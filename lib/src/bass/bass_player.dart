// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';
import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/src/bass/bass_fx.dart';
import 'package:coriander_player/src/bass/bass_wasapi.dart' as BASS;
import 'package:coriander_player/utils.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:path/path.dart' as path;
import 'package:coriander_player/src/bass/bass.dart' as BASS;
import 'dart:ffi' as ffi;

enum PlayerState {
  /// stop() has been called or the end of an audio has been reached
  stopped,

  /// start() has been called
  playing,

  /// pause() has been called
  paused,

  /// BASS_Pause() has been called or stopping unexpectedly (eg. a USB soundcard being disconnected).
  /// In either case, playback will be resumed by BASS_Start.
  pausedDevice,

  ///Playback of the stream has been stalled due to a lack of sample data.
  ///Playback will automatically resume once there is sufficient data to do so.
  stalled,

  /// the end of an audio has been reached
  completed,

  unknown,
}

const BASS_PLUGINS = [
  "BASS\\bassape.dll",
  "BASS\\bassdsd.dll",
  "BASS\\bassflac.dll",
  "BASS\\bassmidi.dll",
  "BASS\\bassopus.dll",
  "BASS\\basswv.dll",
];

class BassPlayer {
  late final ffi.DynamicLibrary _bassLib;
  late final ffi.DynamicLibrary _bassWasapiLib;
  late final BASS.Bass _bass;
  late final BASS.BassWasapi _bassWasapi;
  BassFx? _bassFx;
  bool get isBassFxLoaded => _bassFx != null;

  String? _fPath;
  int? _fstream;

  double _rate = 1.0;
  double _pitch = 0.0;

  double get rate => _rate;

  /// 是否启用 wasapi 独占模式
  bool wasapiExclusive = false;

  Timer? _positionUpdater;
  final _positionStreamController = StreamController<double>.broadcast();
  final _playerStateStreamController =
      StreamController<PlayerState>.broadcast();

  /// audio's length in seconds
  double get length {
    if (_fstream == null) return 1.0;
    final len = _bass.BASS_ChannelBytes2Seconds(
      _fstream!,
      _bass.BASS_ChannelGetLength(_fstream!, BASS.BASS_POS_BYTE),
    );
    return len > 0 ? len : 1.0;
  }

  /// current position in seconds
  double get position => _fstream == null
      ? 0.0
      : _bass.BASS_ChannelBytes2Seconds(
          _fstream!,
          _bass.BASS_ChannelGetPosition(_fstream!, BASS.BASS_POS_BYTE),
        );

  PlayerState get playerState {
    if (_fstream == null) {
      return PlayerState.unknown;
    }

    switch (_bass.BASS_ChannelIsActive(_fstream!)) {
      case BASS.BASS_ACTIVE_STOPPED:
        return PlayerState.stopped;
      case BASS.BASS_ACTIVE_PLAYING:
        if (wasapiExclusive) {
          /// wasapi exclusive's channel is a decoding channel,
          /// will be BASS_ACTIVE_PLAYING as long as there is still data to decode.
          /// So here we check BASS_WASAPI_IsStarted to
          /// judge between BASS_ACTIVE_PLAYING and BASS_ACTIVE_PAUSED
          return _bassWasapi.BASS_WASAPI_IsStarted() == BASS.TRUE
              ? PlayerState.playing
              : PlayerState.paused;
        }
        return PlayerState.playing;
      case BASS.BASS_ACTIVE_PAUSED:
        return PlayerState.paused;
      case BASS.BASS_ACTIVE_PAUSED_DEVICE:
        return PlayerState.pausedDevice;
      case BASS.BASS_ACTIVE_STALLED:
        return PlayerState.stalled;
      default:
        return PlayerState.unknown;
    }
  }

  double get volumeDsp {
    if (_fstream == null) return 0;

    final volDsp = ffi.malloc.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>());
    _bass.BASS_ChannelGetAttribute(_fstream!, BASS.BASS_ATTRIB_VOLDSP, volDsp);
    return volDsp.value;
  }

  /// update every 33ms
  Stream<double> get positionStream => _positionStreamController.stream;

  Stream<PlayerState> get playerStateStream =>
      _playerStateStreamController.stream;

  Timer _getPositionUpdater() {
    return Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _positionStreamController.add(position);

      /// check if the channel has completed
      if (playerState == PlayerState.stopped) {
        _playerStateStreamController.add(PlayerState.completed);
      }
    });
  }

  void _bassInit() {
    if (_bass.BASS_Init(
          1,
          48000,
          BASS.BASS_DEVICE_REINIT,
          ffi.nullptr,
          ffi.nullptr,
        ) ==
        0) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_DEVICE:
          throw const FormatException("device is invalid.");
        case BASS.BASS_ERROR_NOTAVAIL:
          throw const FormatException(
            "The BASS_DEVICE_REINIT flag cannot be used when device is -1. Use the real device number instead.",
          );
        case BASS.BASS_ERROR_ALREADY:
          throw const FormatException(
            "The device has already been initialized. The BASS_DEVICE_REINIT flag can be used to request reinitialization.",
          );
        case BASS.BASS_ERROR_ILLPARAM:
          throw const FormatException("win is not a valid window handle.");
        case BASS.BASS_ERROR_DRIVER:
          throw const FormatException("There is no available device driver.");
        case BASS.BASS_ERROR_BUSY:
          throw const FormatException(
            "Something else has exclusive use of the device.",
          );
        case BASS.BASS_ERROR_FORMAT:
          throw const FormatException(
            "The specified format is not supported by the device. Try changing the freq parameter.",
          );
        case BASS.BASS_ERROR_MEM:
          throw const FormatException("There is insufficient memory.");
        case BASS.BASS_ERROR_UNKNOWN:
          throw const FormatException(
            "Some other mystery problem! Maybe Something else has exclusive use of the device.",
          );
      }
    }
  }

  void _startDevice() {
    if (_bass.BASS_Start() == BASS.FALSE) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_INIT:
          _bassInit();
          _startDevice();
          break;
        case BASS.BASS_ERROR_BUSY:
          throw const FormatException(
            "The app's audio has been interrupted and cannot be resumed yet. (iOS only)",
          );
        case BASS.BASS_ERROR_REINIT:
          throw const FormatException(
            "The device is currently being reinitialized or needs to be.",
          );
        case BASS.BASS_ERROR_UNKNOWN:
          throw const FormatException(
            "Some other mystery problem! Maybe Something else has exclusive use of the device.",
          );
      }
    }
  }

  /// load bass.dll from the exe's path\\BASS
  /// ensure that there's bass.dll at path of .exe\\BASS
  /// leave the device's output freq as it is
  BassPlayer() {
    if (Platform.isWindows) {
      try {
        final kernel32 = ffi.DynamicLibrary.open('kernel32.dll');
        final setDllDirectory = kernel32.lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Utf16>),
            int Function(ffi.Pointer<ffi.Utf16>)>('SetDllDirectoryW');
        final bassDir = path
            .join(path.dirname(Platform.resolvedExecutable), "BASS")
            .toNativeUtf16();
        setDllDirectory(bassDir);
        ffi.calloc.free(bassDir);
      } catch (e) {
        LOGGER.e("Failed to SetDllDirectory: $e");
      }
    }

    final bassLibPath = path.join(
      path.dirname(Platform.resolvedExecutable),
      "BASS",
      "bass.dll",
    );
    _bassLib = ffi.DynamicLibrary.open(bassLibPath);
    _bass = BASS.Bass(_bassLib);

    final bassWasapiLibPath = path.join(
      path.dirname(Platform.resolvedExecutable),
      "BASS",
      "basswasapi.dll",
    );
    _bassWasapiLib = ffi.DynamicLibrary.open(bassWasapiLibPath);
    _bassWasapi = BASS.BassWasapi(_bassWasapiLib);

    // load add-ons to avoid using os codec or support more format
    for (final plugin in BASS_PLUGINS) {
      final pluginPathP = plugin.toNativeUtf16() as ffi.Pointer<ffi.Char>;
      final hplugin = _bass.BASS_PluginLoad(pluginPathP, BASS.BASS_UNICODE);

      if (hplugin == 0) {
        final errCode = _bass.BASS_ErrorGetCode();
        LOGGER.w("Failed to load plugin $plugin: Error $errCode");
      }
    }

    try {
      _bassInit();
    } catch (err) {
      LOGGER.e("[bass init] $err");
    }

    // BASS_FX - 加载bass_fx必须在bass初始化之后
    _loadBassFx();
  }

  void _loadBassFx() {
    try {
      final bassFxLibPath = path.join(
        path.dirname(Platform.resolvedExecutable),
        "BASS",
        "bass_fx.dll",
      );
      final bassFxFile = File(bassFxLibPath);
      if (!bassFxFile.existsSync()) {
        LOGGER.w("bass_fx.dll file not found at: $bassFxLibPath");
        return;
      }

      LOGGER.i("Attempting to load bass_fx.dll from: $bassFxLibPath");

      // 方法1: 使用DynamicLibrary.process() - 利用已加载的库符号
      try {
        LOGGER.d("Method 1: Loading with DynamicLibrary.process()");
        final processSym = ffi.DynamicLibrary.process();
        final tempBassFx = BassFx(processSym);
        final version = tempBassFx.BASS_FX_GetVersion();
        _bassFx = tempBassFx;
        LOGGER.i(
            "✓ BASS_FX loaded via process symbols! Version: ${version.toRadixString(16)}");
        return;
      } catch (e) {
        LOGGER.w("Method 1 failed: $e");
      }

      // 方法2: 直接用绝对路径加载
      try {
        LOGGER.d("Method 2: Loading with absolute path");
        final bassFxLib = ffi.DynamicLibrary.open(bassFxLibPath);
        final tempBassFx = BassFx(bassFxLib);
        final version = tempBassFx.BASS_FX_GetVersion();
        _bassFx = tempBassFx;
        LOGGER.i(
            "✓ BASS_FX loaded successfully! Version: ${version.toRadixString(16)}");
        return;
      } catch (e) {
        LOGGER.w("Method 2 failed: $e");
      }

      // 方法3: 用相对路径加载
      try {
        LOGGER.d("Method 3: Loading with relative path");
        final bassFxLib = ffi.DynamicLibrary.open("bass_fx.dll");
        final tempBassFx = BassFx(bassFxLib);
        final version = tempBassFx.BASS_FX_GetVersion();
        _bassFx = tempBassFx;
        LOGGER.i(
            "✓ BASS_FX loaded successfully! Version: ${version.toRadixString(16)}");
        return;
      } catch (e) {
        LOGGER.w("Method 3 failed: $e");
      }

      // 方法4: 尝试只加载dll而不立即验证函数
      try {
        LOGGER.d("Method 4: Loading without immediate version check");
        final bassFxLib = ffi.DynamicLibrary.open(bassFxLibPath);
        _bassFx = BassFx(bassFxLib);
        LOGGER.i("✓ BASS_FX library loaded (version check deferred)");
        return;
      } catch (e) {
        LOGGER.w("Method 4 failed: $e");
      }

      LOGGER.e("❌ All methods to load bass_fx.dll have failed");
    } catch (e) {
      LOGGER.e("Unexpected error during bass_fx loading: $e");
    }
  }

  /// true: 操作成功；false: 操作失败
  bool useExclusiveMode(bool exclusive) {
    final prevState = wasapiExclusive;
    try {
      final lastPos = position;
      if (prevState) {
        _bassWasapi.BASS_WASAPI_Free();
        _bassInit();
      }
      wasapiExclusive = exclusive;
      if (_fstream != null && _fPath != null) {
        setSource(_fPath!);
        setVolumeDsp(AppPreference.instance.playbackPref.volumeDsp);
        seek(lastPos);
        start();
      }
      return true;
    } catch (err) {
      LOGGER.e("[use exclusive mode] $err");
      showTextOnSnackBar(err.toString());
    }
    wasapiExclusive = prevState;
    return false;
  }

  /// if setSource has been called once,
  /// it will pause current channel and free current stream.
  void setSource(String path) {
    if (_fstream != null) {
      _positionUpdater?.cancel();
      freeFStream();
    }
    final pathPointer = path.toNativeUtf16() as ffi.Pointer<ffi.Void>;

    /// 设置 flags 为 BASS_UNICODE 才可以找到文件。
    const flags =
        BASS.BASS_UNICODE | BASS.BASS_SAMPLE_FLOAT | BASS.BASS_ASYNCFILE;
    const exclusiveFlags = flags | BASS.BASS_STREAM_DECODE;
    // 如果要使用 FX，源流必须是 DECODE 的
    const decodeFlags = flags | BASS.BASS_STREAM_DECODE;

    var handle = _bass.BASS_StreamCreateFile(
      BASS.FALSE,
      pathPointer,
      0,
      0,
      wasapiExclusive ? exclusiveFlags : decodeFlags,
    );

    if (handle != 0 && !wasapiExclusive) {
      // 创建 Tempo 流
      // 如果没有加载 bass_fx 或者创建失败，就回退到原始流（但原始流是 decode 的，不能直接播，需要重新创建）
      try {
        if (_bassFx != null) {
          final tempoHandle =
              _bassFx!.BASS_FX_TempoCreate(handle, BASS_FX_FREESOURCE);
          if (tempoHandle != 0) {
            handle = tempoHandle;
          } else {
            // FX 创建失败，回退
            _bass.BASS_StreamFree(handle);
            handle = _bass.BASS_StreamCreateFile(
              BASS.FALSE,
              pathPointer,
              0,
              0,
              flags,
            );
          }
        } else {
          // bass_fx 未加载
          _bass.BASS_StreamFree(handle);
          handle = _bass.BASS_StreamCreateFile(
            BASS.FALSE,
            pathPointer,
            0,
            0,
            flags,
          );
        }
      } catch (e) {
        // bass_fx 未加载等情况
        _bass.BASS_StreamFree(handle);
        handle = _bass.BASS_StreamCreateFile(
          BASS.FALSE,
          pathPointer,
          0,
          0,
          flags,
        );
      }
    } else if (handle != 0 && wasapiExclusive) {
      // exclusive 模式本身就需要 decode 流，不需要 FX
    }

    if (handle != 0) {
      _fstream = handle;
      _fPath = path;

      if (_rate != 1.0) {
        setRate(_rate);
      }
      if (_pitch != 0.0) {
        setPitch(_pitch);
      }
    } else {
      _fstream = null;
      _fPath = null;
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_INIT:
          _bassInit();
          setSource(path);
          break;
        case BASS.BASS_ERROR_NOTAVAIL:
          throw const FormatException(
            "The BASS_STREAM_AUTOFREE flag cannot be combined with the BASS_STREAM_DECODE flag.",
          );
        case BASS.BASS_ERROR_ILLPARAM:
          throw const FormatException(
            "The length must be specified when streaming from memory.",
          );
        case BASS.BASS_ERROR_FILEOPEN:
          throw const FormatException("The file could not be opened.");
        case BASS.BASS_ERROR_FILEFORM:
          throw const FormatException(
            "The file's format is not recognised/supported.",
          );
        case BASS.BASS_ERROR_NOTAUDIO:
          throw const FormatException(
            "The file does not contain audio, or it also contains video and videos are disabled.",
          );
        case BASS.BASS_ERROR_CODEC:
          throw const FormatException(
            "The file uses a codec that is not available/supported. This can apply to WAV and AIFF files.",
          );
        case BASS.BASS_ERROR_FORMAT:
          throw const FormatException("The sample format is not supported.");
        case BASS.BASS_ERROR_SPEAKER:
          throw const FormatException(
            "The specified SPEAKER flags are invalid.",
          );
        case BASS.BASS_ERROR_MEM:
          throw const FormatException("There is insufficient memory.");
        case BASS.BASS_ERROR_NO3D:
          throw const FormatException("Could not initialize 3D support.");
        case BASS.BASS_ERROR_UNKNOWN:
          throw const FormatException("Some other mystery problem!");
      }
    }
  }

  /// [BASS_ATTRIB_VOLDSP] attribute does have direct effect on decoding/recording channels.
  void setVolumeDsp(double volume) {
    if (_fstream == null) return;

    if (_bass.BASS_ChannelSetAttribute(
          _fstream!,
          BASS.BASS_ATTRIB_VOLDSP,
          volume,
        ) ==
        0) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_HANDLE:
          throw const FormatException("handle is not a valid channel.");
        case BASS.BASS_ERROR_ILLTYPE:
          throw const FormatException("attrib is not valid.");
        case BASS.BASS_ERROR_ILLPARAM:
          throw const FormatException("value is not valid.");
      }
    }
  }

  void setRate(double rate) {
    _rate = rate;
    if (_fstream == null) return;

    // 尝试设置 Tempo (百分比变化)
    // 1.0 -> 0%, 1.5 -> 50%, 0.5 -> -50%
    final tempo = (_rate - 1.0) * 100.0;

    // 优先尝试使用 BASS_FX 的 Tempo 属性
    if (_bass.BASS_ChannelSetAttribute(
          _fstream!,
          BASS_ATTRIB_TEMPO,
          tempo,
        ) ==
        0) {
      // 如果失败（例如不是 Tempo 流），回退到原来的采样率改变方式 (变速变调)
      // 获取当前流的原始采样率
      final freqPtr = ffi.malloc.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>());
      // 注意：这里我们无法轻易获取"原始"采样率，如果已经改变过。
      // 但通常 BASS_ATTRIB_FREQ 读出来的是当前的。
      // 简便起见，如果不支持 Tempo，我们暂时不做处理，或者需要在创建流时记录原始采样率。
      // 考虑到兼容性，如果 bass_fx 不存在，_fstream 就是普通流，
      // 这时我们应该读取当前 freq 然后根据 _rate 调整。
      // 但由于 _baseFreq 在重构中移除了，这里为了稳健，先尝试获取当前频率

      if (_bass.BASS_ChannelGetAttribute(
              _fstream!, BASS.BASS_ATTRIB_FREQ, freqPtr) !=
          0) {
        // 这里有个问题：如果多次调用 setRate，基于当前 freq 修改会导致累积误差。
        // 理想情况是我们在 setSource 时保存了 _baseFreq。
        // 但由于我们现在主推 bass_fx，这里作为 fallback 可以暂不实现复杂逻辑，
        // 或者仅仅在控制台输出警告。
        ffi.malloc.free(freqPtr);
        LOGGER.w(
            "BASS_ATTRIB_TEMPO failed, and fallback implementation is skipped.");
      } else {
        ffi.malloc.free(freqPtr);
      }
    }
  }

  void setPitch(double pitch) {
    _pitch = pitch;
    if (_fstream == null) return;

    _bass.BASS_ChannelSetAttribute(
      _fstream!,
      BASS_ATTRIB_TEMPO_PITCH,
      pitch,
    );
  }

  void _bassWasapiInit() {
    if (_bassWasapi.BASS_WASAPI_Init(
          -1,
          0,
          0,
          BASS.BASS_WASAPI_EXCLUSIVE | BASS.BASS_WASAPI_EVENT,
          0.05,
          0,
          ffi.Pointer<BASS.WASAPIPROC>.fromAddress(-1),
          ffi.Pointer<ffi.Void>.fromAddress(_fstream!),
        ) ==
        BASS.FALSE) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_WASAPI:
          throw const FormatException("WASAPI is not available.");
        case BASS.BASS_ERROR_DEVICE:
          throw const FormatException("device is invalid.");
        case BASS.BASS_ERROR_ALREADY:
          _bassWasapi.BASS_WASAPI_Free();
          _bassWasapiInit();
          break;
        case BASS.BASS_ERROR_NOTAVAIL:
          throw const FormatException(
            "Exclusive mode and/or event-driven buffering is unavailable on the device, or WASAPIPROC_PUSH is unavailable on input devices and when using event-driven buffering.",
          );
        case BASS.BASS_ERROR_DRIVER:
          throw const FormatException("The driver could not be initialized.");
        case BASS.BASS_ERROR_HANDLE:
          throw const FormatException(
            "The BASS channel handle in user is invalid, or not of the required type.",
          );
        case BASS.BASS_ERROR_FORMAT:
          throw const FormatException(
            "The specified format (or that of the BASS channel) is not supported by the device. If the BASS_WASAPI_AUTOFORMAT flag was specified, no other format could be found either.",
          );
        case BASS.BASS_ERROR_BUSY:
          throw const FormatException(
            "The device is already in use, eg. another process may have initialized it in exclusive mode.",
          );
        case BASS.BASS_ERROR_INIT:
          _bassInit();
          _bassWasapiInit();
          break;
        case BASS.BASS_ERROR_WASAPI_BUFFER:
          throw const FormatException(
            "buffer is too large or small (exclusive mode only).",
          );
        case BASS.BASS_ERROR_WASAPI_CATEGORY:
          throw const FormatException(
            "The category/raw mode could not be set.",
          );
        case BASS.BASS_ERROR_WASAPI_DENIED:
          throw const FormatException(
            "Access to the device is denied. This could be due to privacy settings.",
          );
        case BASS.BASS_ERROR_UNKNOWN:
          throw const FormatException("Some other mystery problem!");
      }
    }
  }

  void _start_wasapiExclusive() {
    _bassWasapiInit();

    if (_bassWasapi.BASS_WASAPI_Start() == BASS.FALSE) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_INIT:
          _bassWasapiInit();
          _start_wasapiExclusive();
          break;
        case BASS.BASS_ERROR_UNKNOWN:
          throw const FormatException("Some other mystery problem!");
      }
    }
    _playerStateStreamController.add(playerState);
    _positionUpdater = _getPositionUpdater();
  }

  /// start/resume channel
  ///
  /// do nothing if [setSource] hasn't been called
  void start() {
    if (_fstream == null) return;

    if (wasapiExclusive) {
      return _start_wasapiExclusive();
    }
    if (_bass.BASS_ChannelStart(_fstream!) == 0) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_HANDLE:
          throw const FormatException("handle is not a valid channel.");
        case BASS.BASS_ERROR_DECODE:
          throw const FormatException(
            "handle is a decoding channel, so cannot be played.",
          );
        case BASS.BASS_ERROR_START:
          _startDevice();
          start();
          break;
      }
    }

    _playerStateStreamController.add(playerState);
    _positionUpdater = _getPositionUpdater();
  }

  void _pause_wasapiExclusive() {
    if (_bassWasapi.BASS_WASAPI_Stop(BASS.FALSE) == BASS.TRUE) {
      _playerStateStreamController.add(playerState);
      _positionUpdater?.cancel();
    }
  }

  /// pause channel, call [start] to resume channel
  ///
  /// do nothing if [setSource] hasn't been called
  void pause() {
    if (_fstream == null) return;

    if (wasapiExclusive) {
      return _pause_wasapiExclusive();
    }

    if (_bass.BASS_ChannelPause(_fstream!) == 0) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_HANDLE:
          throw const FormatException("handle is not a valid channel.");
        case BASS.BASS_ERROR_DECODE:
          throw const FormatException(
            "handle is a decoding channel, so cannot be played or paused.",
          );
        case BASS.BASS_ERROR_NOPLAY:
          throw const FormatException("The channel is not playing.");
      }
    }

    _playerStateStreamController.add(playerState);
    _positionUpdater?.cancel();
  }

  /// set channel's position to given [position]
  /// don't check if the position is valid.
  ///
  /// do nothing if [setSource] hasn't been called
  void seek(double position) {
    if (_fstream == null) return;

    if (_bass.BASS_ChannelSetPosition(
          _fstream!,
          _bass.BASS_ChannelSeconds2Bytes(_fstream!, position),
          BASS.BASS_POS_BYTE,
        ) ==
        0) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_HANDLE:
          throw const FormatException("handle is not a valid channel.");
        case BASS.BASS_ERROR_NOTFILE:
          throw const FormatException("The stream is not a file stream.");
        case BASS.BASS_ERROR_POSITION:
          throw const FormatException(
            "The requested position is invalid, eg. it is beyond the end or the download has not yet reached it.",
          );
        case BASS.BASS_ERROR_NOTAVAIL:
          throw const FormatException(
            "The requested mode is not available. Invalid flags are ignored and do not result in this error.",
          );
        case BASS.BASS_ERROR_UNKNOWN:
          throw const FormatException("Some other mystery problem!");
      }
    }
  }

  /// It is not necessary to individually free the samples/streams/musics
  /// as these are all automatically freed after [setSource] or [free] is called.
  ///
  /// do nothing if [setSource] hasn't been called
  void freeFStream() {
    if (_fstream == null) return;

    if (_bass.BASS_StreamFree(_fstream!) == 0) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_HANDLE:
          LOGGER.w("StreamFree is called on a invalid handle.");
          break;
        case BASS.BASS_ERROR_NOTAVAIL:
          throw const FormatException(
            "Device streams (STREAMPROC_DEVICE) cannot be freed.",
          );
      }
    }
  }

  /// Frees all resources used by the output device,
  /// including all its samples, streams and MOD musics.
  ///
  /// Also free the bass.dll.
  void free() {
    if (wasapiExclusive) {
      _bassWasapi.BASS_WASAPI_Free();
    }

    if (_bass.BASS_Free() == 0) {
      switch (_bass.BASS_ErrorGetCode()) {
        case BASS.BASS_ERROR_INIT:
          LOGGER.w("BASS_Free is called before BASS_Init complete normally.");
          break;
        case BASS.BASS_ERROR_BUSY:
          throw const FormatException(
            "The device is currently being reinitialized.",
          );
      }
    }

    _bassWasapiLib.close();
    _bassLib.close();

    _positionUpdater?.cancel();
    _playerStateStreamController.close();
    _positionStreamController.close();
  }
}
