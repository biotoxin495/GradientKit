# GradientKit — A standalone UIGradient effect library

**GradientKit** is a small, dependency-free Roblox module for creating, reusing, and animating `UIGradient` objects. It provides built-in effects for buttons, cards, titles, backgrounds, and other Roblox UI without requiring a UI framework or service container.

GradientKit can work with gradients authored in Studio or create them automatically. Each active effect owns its tweens and connections, returns a controller for direct control, and restores the gradient's original state when it stops.

## Quick example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GradientKit = require(ReplicatedStorage.Packages.GradientKit)

local controller = GradientKit.Apply(script.Parent.Button, "Shine", {
	Duration = 0.8,
	Delay = 2,
})

-- Stop the effect whenever the owning UI is torn down.
controller:Stop()
```

`Apply` reuses the first `UIGradient` under the target or creates one when necessary.

## ✨ Features

* Fully standalone and dependency-free
* Works with existing Studio-authored `UIGradient` objects
* Creates gradients automatically when applying an effect to a `GuiObject`
* One active GradientKit effect per `UIGradient`
* Automatically stops the previous effect on the same gradient
* Built-in shine, hover, rainbow, scrolling, rotation, sweep, press, and palette effects
* Typed public APIs and exported Luau options
* Configurable tween timing, easing, colors, offsets, and rotation
* Interaction targets for hover and press effects
* Restores original gradient properties when stopped by default
* Optional cleanup of gradients created by `Apply`
* Cleans up when a gradient is destroyed
* Supports friendly effect aliases such as `Flow` and `Activated`

## 📖 Basic usage

Copy `GradientKit` into your project and require it from a client script. UI interaction and animation should normally run on the client.

### Applying an effect

```lua
local controller = GradientKit.Apply(button, "Shine")

if controller:IsRunning() then
	print("The gradient effect is active")
end
```

The target must be a `GuiObject`. `Apply` uses an existing child `UIGradient` when one is available; otherwise it creates a gradient named `Gradient`.

### Using an existing UIGradient

Create and style the gradient yourself in Studio, then start an effect on it:

```lua
local button = script.Parent.Button
local gradient = button.UIGradient

local controller = GradientKit.Start(gradient, "Hover", {
	Duration = 0.35,
})
```

For interactive effects, `Start` uses the gradient's parent as the interaction target when that parent is a `GuiObject`. Override it when a different object should receive input:

```lua
GradientKit.Start(label.UIGradient, "Hover", {
	InteractionTarget = button,
})
```

### Creating a gradient

```lua
local gradient = GradientKit.Create(frame, {
	Name = "BackgroundGradient",
	Colors = {
		Color3.fromRGB(255, 90, 150),
		Color3.fromRGB(100, 110, 255),
	},
	Rotation = 45,
})
```

Use either `Colors` for a palette or `Color` for a complete `ColorSequence`.

### Targeting one of several gradients

When a `GuiObject` contains multiple gradients, pass `GradientName` to `Apply`:

```lua
GradientKit.Apply(frame, "Rotate", {
	GradientName = "BackgroundGradient",
})
```

### Included effects

* `Shine` — applies a bright center band and sweeps it across the UI.
* `Hover` — moves a gradient into view on hover and alternates its exit direction.
* `HoverStay` — slides continuously while hovered and pauses when the pointer leaves.
* `Rainbow` — generates an HSV rainbow palette and cycles it across the gradient.
* `Scroll` / `Flow` — continuously moves the current gradient from one offset to another.
* `Rotate` — continuously rotates the gradient while preserving its colors and offset.
* `Sweep` — periodically sweeps the current gradient without imposing a color style.
* `Pressed` / `Activated` — moves and optionally rotates the gradient while pressed.
* `ColorCycle` — continuously cycles through a developer-defined palette of three or more colors.

## Effect examples

### Shine

```lua
GradientKit.Apply(button, "Shine", {
	BaseColor = Color3.fromRGB(255, 80, 160),
	ShineColor = Color3.fromRGB(255, 235, 250),
	Duration = 0.8,
	Delay = 2,
	ShinesPerBurst = 2,
	Rotation = 45,
})
```

### Hover

```lua
GradientKit.Apply(button, "Hover", {
	Colors = {
		Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(80, 255, 140),
		Color3.fromRGB(80, 170, 255),
	},
	Duration = 0.4,
})
```

### HoverStay

```lua
GradientKit.Apply(button, "HoverStay", {
	Colors = {
		Color3.fromRGB(255, 100, 155),
		Color3.fromRGB(95, 180, 255),
	},
	Duration = 2.5,
})
```

### Rainbow

```lua
GradientKit.Apply(title, "Rainbow", {
	Duration = 1,
	Steps = 18,
	Saturation = 1,
	Value = 1,
})
```

Providing at least three colors through `Colors` makes `Rainbow` use that palette instead of generating HSV colors.

### Scroll / Flow

```lua
GradientKit.Apply(frame, "Flow", {
	StartOffset = Vector2.new(-1, 0),
	EndOffset = Vector2.new(1, 0),
	Duration = 3,
	Rotation = 20,
})
```

### Rotate

```lua
GradientKit.Apply(frame, "Rotate", {
	Duration = 5,
	Clockwise = true,
	Degrees = 360,
})
```

Set `Clockwise = false` for counter-clockwise rotation.

### Sweep

```lua
GradientKit.Apply(card, "Sweep", {
	Duration = 0.75,
	Delay = 2.25,
	StartOffset = Vector2.new(-1, 0),
	EndOffset = Vector2.new(1, 0),
})
```

### Pressed / Activated

```lua
GradientKit.Apply(button, "Pressed", {
	Duration = 0.12,
	RestOffset = Vector2.new(0, 0),
	PressedOffset = Vector2.new(0.1, 0),
})
```

The gradient can also rotate slightly during the press:

```lua
GradientKit.Apply(button, "Activated", {
	PressedOffset = Vector2.new(0.08, 0),
	RestRotation = 0,
	PressedRotation = 8,
})
```

### ColorCycle

```lua
GradientKit.Apply(title, "ColorCycle", {
	Colors = {
		Color3.fromRGB(255, 90, 130),
		Color3.fromRGB(255, 200, 80),
		Color3.fromRGB(90, 220, 255),
		Color3.fromRGB(165, 100, 255),
	},
	Duration = 1.2,
})
```

`ColorCycle` requires at least three colors.

## Preserving your own gradient style

Some effects have built-in visual styles. `Shine` creates a base/shine color sequence and `Hover` provides a default palette. Disable those defaults when the gradient's existing colors should remain in control:

```lua
GradientKit.Start(gradient, "Shine", {
	UseDefaultStyle = false,
})
```

`SetupDefaults` is accepted as a backward-compatible alias for `UseDefaultStyle`.

`Scroll`, `Rotate`, `Sweep`, and `Pressed` preserve the existing gradient style unless colors are explicitly supplied.

## Stopping effects

### Stop with the controller

```lua
local controller = GradientKit.Apply(button, "Shine")
controller:Stop()
```

### Stop with the gradient or controller

```lua
GradientKit.Stop(button.UIGradient)
GradientKit.Stop(controller)
```

### Stop every active effect

```lua
local stoppedCount = GradientKit.StopAll()
```

`Stop` returns whether an active effect was found. `StopAll` returns the number of controllers that were stopped. Calling `Stop` with no target also stops all active effects.

## ⚙️ API

### `GradientKit.Create(guiObject, properties?) -> UIGradient`

Creates and parents a new `UIGradient` under `guiObject`.

Supported properties are `Name`, `Enabled`, `Color`, `Colors`, `Transparency`, `Offset`, and `Rotation`.

### `GradientKit.Apply(guiObject, effectName, options?) -> Controller`

Applies an effect directly to a `GuiObject`, reusing a matching existing gradient or creating one when necessary. `GradientName` selects a specific gradient by name.

### `GradientKit.Start(gradient, effectName, options?) -> Controller`

Starts an effect on a specific `UIGradient`. Starting another effect on the same gradient automatically stops the previous controller first.

### `GradientKit.Stop(target?) -> boolean`

Stops an effect using its controller or `UIGradient`. With no target, all active effects are stopped and the return value indicates whether any were active.

### `GradientKit.StopAll() -> number`

Stops all active effects and returns the number stopped.

### `GradientKit.IsActive(gradient) -> boolean`

Returns whether the gradient currently has an active GradientKit controller.

### `GradientKit.GetController(gradient) -> Controller?`

Returns the active controller for the gradient, if one exists.

### Controller methods

```lua
controller:Stop() -> boolean
controller:IsRunning() -> boolean
```

## Complete configuration reference

### Gradient properties (`GradientKit.Create`)

| Property | Type | Description |
| --- | --- | --- |
| `Name` | `string?` | Name assigned to the new gradient. Defaults to `"Gradient"`. |
| `Enabled` | `boolean?` | Whether the gradient is enabled. |
| `Color` | `ColorSequence?` | Complete color sequence to apply. |
| `Colors` | `{ Color3 }?` | Colors converted into evenly spaced keypoints. |
| `Transparency` | `NumberSequence?` | Transparency sequence to apply. |
| `Offset` | `Vector2?` | Initial gradient offset. |
| `Rotation` | `number?` | Initial gradient rotation. |

### Effect options

All options are optional. Unsupported options are ignored by effects that do not use them.

| Option | Type | Used by |
| --- | --- | --- |
| `Duration` | `number?` | Tween-based effects |
| `EasingStyle` | `Enum.EasingStyle?` | Tween-based effects |
| `EasingDirection` | `Enum.EasingDirection?` | Tween-based effects |
| `DelayTime` | `number?` | Tween creation |
| `Reverses` | `boolean?` | Effects allowing repeat options |
| `RepeatCount` | `number?` | Effects allowing repeat options |
| `InteractionTarget` | `GuiObject?` | `Hover`, `HoverStay`, `Pressed` |
| `RestoreOnStop` | `boolean?` | All effects; defaults to restoring |
| `DestroyOnStop` | `boolean?` | Gradients created by `Apply` |
| `UseDefaultStyle` | `boolean?` | `Shine`, `Hover`, `HoverStay` |
| `SetupDefaults` | `boolean?` | Backward-compatible alias |
| `Colors` | `{ Color3 }?` | Palette and color effects |
| `StartOffset` | `Vector2?` | Offset-based effects |
| `EndOffset` | `Vector2?` | Offset-based effects |
| `Rotation` | `number?` | Effects with configurable rotation |
| `BaseColor` | `Color3?` | `Shine` |
| `ShineColor` | `Color3?` | `Shine` |
| `Delay` | `number?` | `Shine`, `Sweep` |
| `ShinesPerBurst` | `number?` | `Shine` |
| `Steps` | `number?` | Generated `Rainbow` palettes |
| `Saturation` | `number?` | Generated `Rainbow` palettes |
| `Value` | `number?` | Generated `Rainbow` palettes |
| `StartRotation` | `number?` | `Rotate` |
| `Clockwise` | `boolean?` | `Rotate` |
| `Degrees` | `number?` | `Rotate` |
| `RestOffset` | `Vector2?` | `Pressed` |
| `PressedOffset` | `Vector2?` | `Pressed` |
| `PressedRotation` | `number?` | `Pressed` |
| `RestRotation` | `number?` | `Pressed` |
| `GradientName` | `string?` | `Apply` |

## Effect aliases

GradientKit ignores spaces, underscores, hyphens, and capitalization when resolving effect names.

```text
Shine / Shimmer
HoverStay / Hover Stay / hover-stay
Rainbow / RGB
Scroll / Flow
Rotate / Spin
Pressed / Press / Activated / Activate / Click
ColorCycle / ColourCycle / Cycle / ColorShift
```

## 📝 Notes

* GradientKit is intended for client-side UI.
* `Hover`, `HoverStay`, and `Pressed` require an interaction target. `Apply` supplies the target automatically; `Start` resolves it from the gradient's parent when possible.
* Stopping an effect restores `Enabled`, `Color`, `Transparency`, `Offset`, and `Rotation` from before the effect started unless `RestoreOnStop = false`.
* `DestroyOnStop` only destroys gradients created by `GradientKit.Apply`; it never destroys a gradient supplied by the developer.
* Destroying a `UIGradient` automatically removes its active controller and tracked connections.
* Effects are self-contained and use Roblox `TweenService` plus lightweight task loops instead of a permanent global frame-by-frame scheduler.

## 🛠️ Installation

Place the package somewhere accessible to your client UI code, for example:

```text
ReplicatedStorage
└── Packages
    └── GradientKit
```

Then require it from a `LocalScript`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GradientKit = require(ReplicatedStorage.Packages.GradientKit)
```

GradientKit does not depend on this exact folder structure; it is only a suggested organization.

## Showcase

A separate showcase place can present every included effect in a compact gallery and demonstrate both automatically generated gradients and Studio-authored `UIGradient` objects.

Showcase game: [ADD SHOWCASE URL]

made with ❤️ by biotoxin495
