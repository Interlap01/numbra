// Stand-in for ImageIO, supplied by this project for the MobAI preview engine.
//
// Sources/Engine/PBNEngine.swift carries `import ImageIO`, but the engine is
// pure CoreGraphics/array math (see CLAUDE.md: "pure, platform-agnostic
// image→data logic") and references no ImageIO symbol. Without this file the
// preview blocks the import, which strands PBNEngine.swift and, through it,
// AppModel and every screen that touches the model.
//
// Empty on purpose: add a declaration here only if the app starts using one.

import Foundation
