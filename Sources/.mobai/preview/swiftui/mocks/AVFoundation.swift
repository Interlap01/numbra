// Generated from MobAI normalized Apple SDK IR.
// Module: AVFoundation
// Extracted SDK modules: AVFoundation, AVFoundation.AVAnimation, AVFoundation.AVAsset, AVFoundation.AVAssetCache, AVFoundation.AVAssetDownloadStorageManager, AVFoundation.AVAssetDownloadTask, AVFoundation.AVAssetExportSession, AVFoundation.AVAssetImageGenerator, AVFoundation.AVAssetPlaybackAssistant, AVFoundation.AVAssetReader, AVFoundation.AVAssetReaderOutput, AVFoundation.AVAssetResourceLoader, AVFoundation.AVAssetSegmentReport, AVFoundation.AVAssetTrack, AVFoundation.AVAssetTrackGroup, AVFoundation.AVAssetTrackSegment, AVFoundation.AVAssetVariant, AVFoundation.AVAssetWriter, AVFoundation.AVAssetWriterInput, AVFoundation.AVAsynchronousKeyValueLoading, AVFoundation.AVAudioBuffer, AVFoundation.AVAudioChannelLayout, AVFoundation.AVAudioConnectionPoint, AVFoundation.AVAudioConverter, AVFoundation.AVAudioEngine, AVFoundation.AVAudioEnvironmentNode, AVFoundation.AVAudioFile, AVFoundation.AVAudioFormat, AVFoundation.AVAudioIONode, AVFoundation.AVAudioMix, AVFoundation.AVAudioMixerNode, AVFoundation.AVAudioMixing, AVFoundation.AVAudioNode, AVFoundation.AVAudioPlayer, AVFoundation.AVAudioPlayerNode, AVFoundation.AVAudioProcessingSettings, AVFoundation.AVAudioRecorder, AVFoundation.AVAudioSequencer, AVFoundation.AVAudioSession, AVFoundation.AVAudioSessionDeprecated, AVFoundation.AVAudioSessionRoute, AVFoundation.AVAudioSessionTypes, AVFoundation.AVAudioSettings, AVFoundation.AVAudioTime, AVFoundation.AVAudioTypes, AVFoundation.AVAudioUnit, AVFoundation.AVAudioUnitComponent, AVFoundation.AVAudioUnitDelay, AVFoundation.AVAudioUnitDistortion, AVFoundation.AVAudioUnitEQ, AVFoundation.AVAudioUnitEffect, AVFoundation.AVAudioUnitGenerator, AVFoundation.AVAudioUnitMIDIInstrument, AVFoundation.AVAudioUnitReverb, AVFoundation.AVAudioUnitSampler, AVFoundation.AVAudioUnitTimeEffect, AVFoundation.AVAudioUnitTimePitch, AVFoundation.AVAudioUnitVarispeed, AVFoundation.AVBase, AVFoundation.AVCameraCalibrationData, AVFoundation.AVCaption, AVFoundation.AVCaptionConversionValidator, AVFoundation.AVCaptionFormatConformer, AVFoundation.AVCaptionGroup, AVFoundation.AVCaptionGrouper, AVFoundation.AVCaptionRenderer, AVFoundation.AVCaptionSettings, AVFoundation.AVCaptureAudioDataOutput, AVFoundation.AVCaptureAudioPreviewOutput, AVFoundation.AVCaptureControl, AVFoundation.AVCaptureDataOutputSynchronizer, AVFoundation.AVCaptureDepthDataOutput, AVFoundation.AVCaptureDeskViewApplication, AVFoundation.AVCaptureDevice, AVFoundation.AVCaptureExternalDisplayConfigurator, AVFoundation.AVCaptureFileOutput, AVFoundation.AVCaptureIndexPicker, AVFoundation.AVCaptureInput, AVFoundation.AVCaptureMetadataOutput, AVFoundation.AVCaptureOutput, AVFoundation.AVCaptureOutputBase, AVFoundation.AVCapturePhotoOutput, AVFoundation.AVCaptureReactions, AVFoundation.AVCaptureSession, AVFoundation.AVCaptureSessionPreset, AVFoundation.AVCaptureSlider, AVFoundation.AVCaptureSpatialAudioMetadataSampleGenerator, AVFoundation.AVCaptureStillImageOutput, AVFoundation.AVCaptureSystemExposureBiasSlider, AVFoundation.AVCaptureSystemPressure, AVFoundation.AVCaptureSystemZoomSlider, AVFoundation.AVCaptureTimecodeGenerator, AVFoundation.AVCaptureVideoDataOutput, AVFoundation.AVCaptureVideoPreviewLayer, AVFoundation.AVComposition, AVFoundation.AVCompositionTrack, AVFoundation.AVCompositionTrackSegment, AVFoundation.AVContentKeySession, AVFoundation.AVContinuityDevice, AVFoundation.AVDepthData, AVFoundation.AVDisplayCriteria, AVFoundation.AVError, AVFoundation.AVExternalStorageDevice, AVFoundation.AVExternalSyncDevice, AVFoundation.AVFAudio, AVFoundation.AVFCapture, AVFoundation.AVFCore, AVFoundation.AVGeometry, AVFoundation.AVMIDIPlayer, AVFoundation.AVMediaFormat, AVFoundation.AVMediaSelection, AVFoundation.AVMediaSelectionGroup, AVFoundation.AVMetadataFormat, AVFoundation.AVMetadataIdentifiers, AVFoundation.AVMetadataItem, AVFoundation.AVMetadataObject, AVFoundation.AVMetrics, AVFoundation.AVMovie, AVFoundation.AVMovieTrack, AVFoundation.AVOutputSettingsAssistant, AVFoundation.AVPlaybackCoordinationMedium, AVFoundation.AVPlaybackCoordinator, AVFoundation.AVPlayer, AVFoundation.AVPlayerInterstitialEventController, AVFoundation.AVPlayerItem, AVFoundation.AVPlayerItemIntegratedTimeline, AVFoundation.AVPlayerItemMediaDataCollector, AVFoundation.AVPlayerItemOutput, AVFoundation.AVPlayerItemTrack, AVFoundation.AVPlayerLayer, AVFoundation.AVPlayerLooper, AVFoundation.AVPlayerMediaSelectionCriteria, AVFoundation.AVPlayerOutput, AVFoundation.AVPortraitEffectsMatte, AVFoundation.AVQueuedSampleBufferRendering, AVFoundation.AVRenderedCaptionImage, AVFoundation.AVRouteDetector, AVFoundation.AVSampleBufferAudioRenderer, AVFoundation.AVSampleBufferDisplayLayer, AVFoundation.AVSampleBufferGenerator, AVFoundation.AVSampleBufferRenderSynchronizer, AVFoundation.AVSampleBufferVideoRenderer, AVFoundation.AVSampleCursor, AVFoundation.AVSemanticSegmentationMatte, AVFoundation.AVSpatialVideoConfiguration, AVFoundation.AVSpeechSynthesis, AVFoundation.AVSynchronizedLayer, AVFoundation.AVTextStyleRule, AVFoundation.AVTime, AVFoundation.AVTimedMetadataGroup, AVFoundation.AVUtilities, AVFoundation.AVVideoCompositing, AVFoundation.AVVideoComposition, AVFoundation.AVVideoPerformanceMetrics, AVFoundation.AVVideoSettings
// This project copy is editable; catalog expansion only appends missing declarations.

import Foundation


#if canImport(Glibc)
public typealias CFString = String
#endif

public typealias OSStatus = Int32

// mobai-ir-declaration: AVAudioEngine
public struct AVAudioEngine: RawRepresentable, Hashable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = "" }
}

// mobai-ir-declaration: AVAudioFormat
public struct AVAudioFormat: RawRepresentable, Hashable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = "" }
}

// mobai-ir-declaration: AVAudioPlayerNode
public struct AVAudioPlayerNode: RawRepresentable, Hashable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = "" }
}

// mobai-ir-declaration: AVAudioSession
public struct AVAudioSession: RawRepresentable, Hashable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = "" }
}

// mobai-ir-declaration: attach
public extension CMReadySampleBuffer {
    public func attach<Content>(contentKey value0: AVAVContentKey) throws where Content : CoreMedia.CMSampleBuffer.Content {}
}
