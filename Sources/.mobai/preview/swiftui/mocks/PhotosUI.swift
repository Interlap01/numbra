// Generated from MobAI normalized Apple SDK IR.
// Module: PhotosUI
// Extracted SDK modules: PhotosUI, PhotosUI.PHContentEditingController, PhotosUI.PHLivePhotoView, PhotosUI.PHPhotoLibrary_PhotosUISupport, PhotosUI.PHPicker, _PhotosUI_SwiftUI
// This project copy is editable; catalog expansion only appends missing declarations.

import Foundation
import SwiftUI



// mobai-ir-declaration: PHPickerFilter
public struct PHPickerFilter: Hashable {
    public init() {}

    public static var images: PHPickerFilter { .init() }

    public static func any(of value0: [PHPickerFilter]) -> PHPickerFilter { .init() }

    public static func all(of value0: [PHPickerFilter]) -> PHPickerFilter { .init() }

    public static func not(_ value0: PHPickerFilter) -> PHPickerFilter { .init() }
}

// mobai-ir-declaration: PhotosPickerItem
public struct PhotosPickerItem: Hashable {
    public init() {}

    @discardableResult
    public func loadTransferable<T>(type value0: T.Type, completionHandler value1: (Result<T?, any Error>) -> Void) -> Progress where T : CoreTransferable.Transferable { fatalError("preview SDK mock has no inert value for Progress") }

    public func loadTransferable<T>(type value0: T.Type) throws -> T? where T : CoreTransferable.Transferable { nil }
}

// mobai-ir-declaration: PhotosPickerSelectionBehavior
public struct PhotosPickerSelectionBehavior: Hashable {
    public init() {}

    public static var default: PhotosPickerSelectionBehavior { .init() }

    public static var continuous: PhotosPickerSelectionBehavior { .init() }
}

// mobai-ir-declaration: photosPicker
public extension View {
    public func photosPicker(isPresented value0: SwiftUI.Binding<Bool>, selection value1: SwiftUI.Binding<PhotosPickerItem?>, matching value2: PHPickerFilter? = nil, preferredItemEncoding value3: PhotosPickerItem.EncodingDisambiguationPolicy = .init()) -> some SwiftUI.View { SwiftUI.Text("PhotosUI surface unavailable in preview") }

    public func photosPicker(isPresented value0: SwiftUI.Binding<Bool>, selection value1: SwiftUI.Binding<[PhotosPickerItem]>, maxSelectionCount value2: Int? = nil, selectionBehavior value3: PhotosPickerSelectionBehavior = .init(), matching value4: PHPickerFilter? = nil, preferredItemEncoding value5: PhotosPickerItem.EncodingDisambiguationPolicy = .init()) -> some SwiftUI.View { SwiftUI.Text("PhotosUI surface unavailable in preview") }

    public func photosPicker(isPresented value0: SwiftUI.Binding<Bool>, selection value1: SwiftUI.Binding<PhotosPickerItem?>, matching value2: PHPickerFilter? = nil, preferredItemEncoding value3: PhotosPickerItem.EncodingDisambiguationPolicy = .init(), photoLibrary value4: Photos.PHPhotoLibrary) -> some SwiftUI.View { SwiftUI.Text("PhotosUI surface unavailable in preview") }

    public func photosPicker(isPresented value0: SwiftUI.Binding<Bool>, selection value1: SwiftUI.Binding<[PhotosPickerItem]>, maxSelectionCount value2: Int? = nil, selectionBehavior value3: PhotosPickerSelectionBehavior = .init(), matching value4: PHPickerFilter? = nil, preferredItemEncoding value5: PhotosPickerItem.EncodingDisambiguationPolicy = .init(), photoLibrary value6: Photos.PHPhotoLibrary) -> some SwiftUI.View { SwiftUI.Text("PhotosUI surface unavailable in preview") }
}
