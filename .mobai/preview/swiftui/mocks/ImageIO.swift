// MobAI curated stand-in: ImageIO
// Managed by the engine while unchanged; edit it and it is yours.
// curated-key: e31bcea2b6f25754
//
// Image decoding for a still preview: nothing decodes here. Every source is
// empty, every count is zero, every property dictionary is nil, so code
// that reads metadata gets "unknown" and code that decodes gets nil and
// keeps its own fallback. The constants exist so the names compile.
//
// Linux has no bridging from String, Data or Dictionary to their
// CoreFoundation twins, so the surface takes `Any` where Apple's takes a
// CF type, and the constants are plain strings. A call site that itself
// casts (`data as CFData`) does not compile here; the build demotes that
// one body to a trap and the screen goes on.

import Foundation
import CoreGraphics

public final class CGImageSource {
    fileprivate init() {}
}
public final class CGImageDestination {
    fileprivate init() {}
}

public typealias CGImageSourceStatus = Int32
public let kCGImageStatusComplete: CGImageSourceStatus = 0
public let kCGImageStatusUnknownType: CGImageSourceStatus = -1
public let kCGImageStatusReadingHeader: CGImageSourceStatus = -2
public let kCGImageStatusIncomplete: CGImageSourceStatus = -3
public let kCGImageStatusInvalidData: CGImageSourceStatus = -4
public let kCGImageStatusUnexpectedEOF: CGImageSourceStatus = -5

public let kCGImageSourceShouldCache = "kCGImageSourceShouldCache"
public let kCGImageSourceShouldCacheImmediately = "kCGImageSourceShouldCacheImmediately"
public let kCGImageSourceCreateThumbnailFromImageAlways = "kCGImageSourceCreateThumbnailFromImageAlways"
public let kCGImageSourceCreateThumbnailFromImageIfAbsent = "kCGImageSourceCreateThumbnailFromImageIfAbsent"
public let kCGImageSourceCreateThumbnailWithTransform = "kCGImageSourceCreateThumbnailWithTransform"
public let kCGImageSourceThumbnailMaxPixelSize = "kCGImageSourceThumbnailMaxPixelSize"
public let kCGImageSourceTypeIdentifierHint = "kCGImageSourceTypeIdentifierHint"
public let kCGImageSourceShouldAllowFloat = "kCGImageSourceShouldAllowFloat"
public let kCGImagePropertyPixelWidth = "PixelWidth"
public let kCGImagePropertyPixelHeight = "PixelHeight"
public let kCGImagePropertyOrientation = "Orientation"
public let kCGImagePropertyDPIWidth = "DPIWidth"
public let kCGImagePropertyDPIHeight = "DPIHeight"
public let kCGImagePropertyExifDictionary = "{Exif}"
public let kCGImagePropertyGPSDictionary = "{GPS}"
public let kCGImagePropertyTIFFDictionary = "{TIFF}"
public let kCGImagePropertyGIFDictionary = "{GIF}"
public let kCGImagePropertyGIFDelayTime = "DelayTime"
public let kCGImagePropertyGIFUnclampedDelayTime = "UnclampedDelayTime"
public let kCGImagePropertyGIFLoopCount = "LoopCount"
public let kCGImagePropertyPNGDictionary = "{PNG}"
public let kCGImagePropertyHEICSDictionary = "{HEICS}"
public let kCGImagePropertyWebPDictionary = "{WebP}"
public let kCGImagePropertyHasAlpha = "HasAlpha"
public let kCGImagePropertyColorModel = "ColorModel"
public let kCGImageDestinationLossyCompressionQuality = "kCGImageDestinationLossyCompressionQuality"
public let kCGImageMetadataShouldExcludeXMP = "kCGImageMetadataShouldExcludeXMP"

public func CGImageSourceCreateWithData(_ data: Any, _ options: Any?) -> CGImageSource? { nil }
public func CGImageSourceCreateWithURL(_ url: Any, _ options: Any?) -> CGImageSource? { nil }
public func CGImageSourceCreateIncremental(_ options: Any?) -> CGImageSource { CGImageSource() }
public func CGImageSourceUpdateData(_ source: CGImageSource, _ data: Any, _ final: Bool) {}
public func CGImageSourceGetCount(_ source: CGImageSource) -> Int { 0 }
public func CGImageSourceGetType(_ source: CGImageSource) -> String? { nil }
public func CGImageSourceGetStatus(_ source: CGImageSource) -> CGImageSourceStatus { kCGImageStatusUnknownType }
public func CGImageSourceGetStatusAtIndex(_ source: CGImageSource, _ index: Int) -> CGImageSourceStatus { kCGImageStatusUnknownType }
public func CGImageSourceCopyProperties(_ source: CGImageSource, _ options: Any?) -> [String: Any]? { nil }
public func CGImageSourceCopyPropertiesAtIndex(_ source: CGImageSource, _ index: Int, _ options: Any?) -> [String: Any]? { nil }
public func CGImageSourceCreateImageAtIndex(_ source: CGImageSource, _ index: Int, _ options: Any?) -> CGImage? { nil }
public func CGImageSourceCreateThumbnailAtIndex(_ source: CGImageSource, _ index: Int, _ options: Any?) -> CGImage? { nil }
public func CGImageSourceCopyTypeIdentifiers() -> [String] { [] }
public func CGImageDestinationCreateWithData(_ data: Any, _ type: String, _ count: Int, _ options: Any?) -> CGImageDestination? { nil }
public func CGImageDestinationCreateWithURL(_ url: Any, _ type: String, _ count: Int, _ options: Any?) -> CGImageDestination? { nil }
public func CGImageDestinationAddImage(_ destination: CGImageDestination, _ image: CGImage, _ properties: Any?) {}
public func CGImageDestinationAddImageFromSource(_ destination: CGImageDestination, _ source: CGImageSource, _ index: Int, _ properties: Any?) {}
public func CGImageDestinationSetProperties(_ destination: CGImageDestination, _ properties: Any?) {}
public func CGImageDestinationFinalize(_ destination: CGImageDestination) -> Bool { false }
public func CGImageDestinationCopyTypeIdentifiers() -> [String] { [] }
