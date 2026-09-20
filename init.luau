--!strict

--   ____               _ _           _ _  ___ _
--  / ___|_ __ __ _  __| (_) ___ _ __ | | |/ (_) |_ 
-- | |  _| '__/ _` |/ _` | |/ _ \ '_ \| | ' /| | __|
-- | |_| | | | (_| | (_| | |  __/ | | | | . \| | |_
--  \____|_|  \__,_|\__,_|_|\___|_| |_|_|_|\_\_|\__|

-- made with ❤️ by biotoxin495

-- A standalone UIGradient creation and animation utility for Roblox UI,
-- intended to run on the client. GradientKit can create or reuse gradients,
-- apply built-in effects, and return disposable controllers for cleanup.
-- It does not require a UI framework or service container.
--
-- Usage:
--   local GradientKit = require(path.to.GradientKit)
--
--   -- Apply an effect to a GuiObject. An existing UIGradient is reused;
--   -- otherwise GradientKit creates one and parents it to the object.
--   local controller = GradientKit.Apply(button, "Shine", options)
--   controller:Stop()                               -- stop one effect
--
--   -- Create and configure a gradient directly.
--   local gradient = GradientKit.Create(frame, properties)
--   GradientKit.Start(gradient, "Rotate", options)  -- animate that gradient
--
--   -- Control effects by their controller or by their UIGradient.
--   GradientKit.Stop(target)                         -- stop one effect
--   GradientKit.Stop()                               -- stop every active effect
--   GradientKit.StopAll()                            -- return count of stopped effects
--   GradientKit.IsActive(gradient)                   -- check active state
--   GradientKit.GetController(gradient)              -- retrieve its controller
--
-- Controller methods:
--   controller:Stop()                                -- restore and stop the effect
--   controller:IsRunning()                           -- check whether it is active
--
-- Effects:
--   Shine        Applies a bright center band and repeatedly sweeps it across UI.
--   Hover        Moves the gradient into view and alternates its exit direction.
--   HoverStay    Slides while hovered and pauses when the pointer leaves.
--   Rainbow      Generates an HSV palette and continuously cycles it.
--   Scroll/Flow  Moves the current gradient between StartOffset and EndOffset.
--   Rotate       Continuously rotates the gradient without changing its colors.
--   Sweep        Periodically sweeps the current gradient without styling it.
--   Pressed      Moves and optionally rotates the gradient during mouse/touch input.
--   ColorCycle   Continuously cycles through a supplied palette of 3+ colors.
--
-- Interactive effects use InteractionTarget when supplied. Otherwise Start uses
-- the gradient's GuiObject parent, and Apply uses the GuiObject it receives.
-- Hover, HoverStay, and Pressed require a valid GuiObject interaction target.
--
-- Configuration (all optional; see GradientProperties/EffectOptions below):
--   Gradient:  Name, Enabled, Color/Colors, Transparency, Offset, Rotation
--   Tween:     Duration, EasingStyle, EasingDirection, DelayTime, Reverses, RepeatCount
--   Lifecycle: RestoreOnStop, DestroyOnStop, UseDefaultStyle, SetupDefaults
--   Targeting: InteractionTarget, GradientName
--   Effects:   Colors, offsets, rotation, palette, shine, and press options
--
-- GradientKit restores Enabled, Color, Transparency, Offset, and Rotation when
-- an effect stops. Set RestoreOnStop = false to keep the animated state.
-- DestroyOnStop only destroys a gradient created by Apply, never one supplied
-- by the developer. Starting a new effect on a gradient stops the old effect.
--
-- Effect aliases ignore capitalization, spaces, underscores, and hyphens:
--   Shine/Shimmer, Rainbow/RGB, Scroll/Flow, Rotate/Spin,
--   Pressed/Press/Activated/Activate/Click,
--   ColorCycle/ColourCycle/Cycle/ColorShift.

local TweenService = game:GetService("TweenService")

local GradientKit = {}

export type EffectName =
	"Shine"
	| "Hover"
	| "HoverStay"
	| "Rainbow"
	| "Scroll"
	| "Flow"
	| "Rotate"
	| "Sweep"
	| "Pressed"
	| "Activated"
	| "ColorCycle"

export type GradientProperties = {
	Name: string?,
	Enabled: boolean?,
	Color: ColorSequence?,
	Colors: { Color3 }?,
	Transparency: NumberSequence?,
	Offset: Vector2?,
	Rotation: number?,
}

export type EffectOptions = {
	-- Shared tween configuration
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	DelayTime: number?,
	Reverses: boolean?,
	RepeatCount: number?,

	-- Shared lifecycle / targeting
	InteractionTarget: GuiObject?,
	RestoreOnStop: boolean?,
	DestroyOnStop: boolean?,
	UseDefaultStyle: boolean?,
	SetupDefaults: boolean?, -- Backward-compatible alias for UseDefaultStyle.

	-- Shared gradient configuration
	Colors: { Color3 }?,
	StartOffset: Vector2?,
	EndOffset: Vector2?,
	Rotation: number?,

	-- Shine / Sweep
	BaseColor: Color3?,
	ShineColor: Color3?,
	Delay: number?,
	ShinesPerBurst: number?,

	-- Rainbow
	Steps: number?,
	Saturation: number?,
	Value: number?,

	-- Rotate
	StartRotation: number?,
	Clockwise: boolean?,
	Degrees: number?,

	-- Pressed
	RestOffset: Vector2?,
	PressedOffset: Vector2?,
	PressedRotation: number?,
	RestRotation: number?,

	-- Apply
	GradientName: string?,
}

export type Controller = {
	Gradient: UIGradient,
	Target: GuiObject?,
	Effect: string,
	Options: EffectOptions,
	Running: boolean,
	OwnsGradient: boolean,
	Stop: (self: Controller) -> boolean,
	IsRunning: (self: Controller) -> boolean,
}

type InternalController = Controller & {
	__gradientKitController: boolean,
	Tweens: { Tween },
	Connections: { RBXScriptConnection },
	Initial: {
		Enabled: boolean,
		Color: ColorSequence,
		Transparency: NumberSequence,
		Offset: Vector2,
		Rotation: number,
	},
}

type EffectFunction = (controller: InternalController) -> ()

local Active: { [UIGradient]: InternalController } = {}
local Effects: { [string]: EffectFunction } = {}

local SUPPORTED_EFFECTS = table.concat({
	"Shine",
	"Hover",
	"HoverStay",
	"Rainbow",
	"Scroll/Flow",
	"Rotate",
	"Sweep",
	"Pressed/Activated",
	"ColorCycle",
}, ", ")

local function defaultStyleEnabled(options: EffectOptions): boolean
	if options.UseDefaultStyle ~= nil then
		return options.UseDefaultStyle
	end

	if options.SetupDefaults ~= nil then
		return options.SetupDefaults
	end

	return true
end

local function makeColorSequence(colors: { Color3 }): ColorSequence
	assert(#colors > 0, "GradientKit requires at least one color.")

	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end

	local keypoints: { ColorSequenceKeypoint } = table.create(#colors)

	for i, color in ipairs(colors) do
		local alpha = (i - 1) / (#colors - 1)
		keypoints[i] = ColorSequenceKeypoint.new(alpha, color)
	end

	return ColorSequence.new(keypoints)
end

local function normalizeEffectName(effectName: string): string?
	local compact = string.lower(tostring(effectName)):gsub("[%s_%-]", "")

	local aliases: { [string]: string } = {
		shine = "shine",
		shimmer = "shine",

		hover = "hover",

		hoverstay = "hoverStay",
		stayhover = "hoverStay",

		rainbow = "rainbow",
		rgb = "rainbow",

		scroll = "scroll",
		flow = "scroll",

		rotate = "rotate",
		spin = "rotate",

		sweep = "sweep",

		pressed = "pressed",
		press = "pressed",
		activated = "pressed",
		activate = "pressed",
		click = "pressed",

		colorcycle = "colorCycle",
		colourcycle = "colorCycle",
		cycle = "colorCycle",
		colorshift = "colorCycle",
		colourshift = "colorCycle",
	}

	return aliases[compact]
end

local function assertGradient(gradient: Instance)
	assert(gradient:IsA("UIGradient"), "GradientKit expected a UIGradient object.")
end

local function assertGuiObject(guiObject: Instance?, effectName: string): GuiObject
	assert(
		guiObject ~= nil and guiObject:IsA("GuiObject"),
		string.format("Gradient effect %q needs an InteractionTarget GuiObject.", effectName)
	)

	return guiObject :: GuiObject
end

local function makeTweenInfo(
	options: EffectOptions,
	defaultDuration: number,
	defaultStyle: Enum.EasingStyle,
	defaultDirection: Enum.EasingDirection,
	allowRepeatOptions: boolean?
): TweenInfo
	local repeatCount = 0
	local reverses = false

	if allowRepeatOptions ~= false then
		repeatCount = if options.RepeatCount ~= nil then options.RepeatCount else 0
		reverses = if options.Reverses ~= nil then options.Reverses else false
	end

	return TweenInfo.new(
		options.Duration or defaultDuration,
		options.EasingStyle or defaultStyle,
		options.EasingDirection or defaultDirection,
		repeatCount,
		reverses,
		options.DelayTime or 0
	)
end

local function trackTween(controller: InternalController, tween: Tween): Tween
	table.insert(controller.Tweens, tween)
	return tween
end

local function trackConnection(controller: InternalController, connection: RBXScriptConnection): RBXScriptConnection
	table.insert(controller.Connections, connection)
	return connection
end

local function cancellableWait(controller: InternalController, seconds: number): boolean
	if seconds <= 0 then
		return controller.Running
	end

	local started = os.clock()

	while controller.Running do
		local remaining = seconds - (os.clock() - started)
		if remaining <= 0 then
			break
		end

		task.wait(math.min(0.1, remaining))
	end

	return controller.Running
end

local function playAndWait(controller: InternalController, tween: Tween): boolean
	if not controller.Running then
		return false
	end

	local finished = false
	local playbackState: Enum.PlaybackState? = nil

	local connection = tween.Completed:Connect(function(state)
		playbackState = state
		finished = true
	end)

	tween:Play()

	while controller.Running and not finished do
		task.wait()
	end

	connection:Disconnect()

	if not controller.Running then
		tween:Cancel()
		return false
	end

	return playbackState == Enum.PlaybackState.Completed
end

local function cancelOtherTweens(controller: InternalController, tweenToPlay: Tween)
	for _, tween in ipairs(controller.Tweens) do
		if tween ~= tweenToPlay then
			tween:Cancel()
		end
	end
end

local function colorAt(colors: { Color3 }, index: number): Color3
	local count = #colors
	return colors[((index - 1) % count) + 1]
end

local function buildRainbowColors(options: EffectOptions): { Color3 }
	local optionColors = options.Colors
	if optionColors ~= nil and #optionColors >= 3 then
		return optionColors
	end

	local steps = math.max(options.Steps or 15, 3)
	local saturation = options.Saturation or 1
	local value = options.Value or 1

	local colors: { Color3 } = table.create(steps)

	for i = 0, steps - 1 do
		colors[i + 1] = Color3.fromHSV(i / steps, saturation, value)
	end

	return colors
end

local function resolveCycleColors(options: EffectOptions): { Color3 }
	local colors = options.Colors
		or {
			Color3.fromRGB(255, 95, 150),
			Color3.fromRGB(255, 210, 90),
			Color3.fromRGB(95, 220, 255),
			Color3.fromRGB(150, 105, 255),
		}

	assert(#colors >= 3, "GradientKit ColorCycle requires at least 3 colors.")
	return colors
end

local function runPaletteCycle(controller: InternalController, colors: { Color3 })
	local gradient = controller.Gradient
	local options = controller.Options
	local startOffset = options.StartOffset or Vector2.new(-1, 0)
	local endOffset = options.EndOffset or Vector2.new(1, 0)
	local keypoint = ColorSequenceKeypoint.new

	gradient.Offset = startOffset
	gradient.Rotation = options.Rotation or 0
	gradient.Color = ColorSequence.new({
		keypoint(0, colorAt(colors, #colors)),
		keypoint(0.5, colorAt(colors, #colors - 1)),
		keypoint(1, colorAt(colors, #colors - 2)),
	})

	local counter = #colors
	local tweenInfo = makeTweenInfo(options, 1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, false)
	local tween = trackTween(
		controller,
		TweenService:Create(gradient, tweenInfo, {
			Offset = endOffset,
		})
	)

	task.spawn(function()
		while controller.Running do
			if not playAndWait(controller, tween) then
				return
			end

			gradient.Offset = startOffset
			gradient.Rotation = (options.Rotation or 0) + 180
			gradient.Color = ColorSequence.new({
				keypoint(0, gradient.Color.Keypoints[1].Value),
				keypoint(0.5, colorAt(colors, counter + 1)),
				keypoint(1, colorAt(colors, counter + 2)),
			})

			counter += 2

			if not playAndWait(controller, tween) then
				return
			end

			gradient.Offset = startOffset
			gradient.Rotation = options.Rotation or 0
			gradient.Color = ColorSequence.new({
				keypoint(0, colorAt(colors, counter + 2)),
				keypoint(0.5, colorAt(colors, counter + 1)),
				keypoint(1, gradient.Color.Keypoints[3].Value),
			})

			counter += 2
		end
	end)
end

-- Shine
-- Applies a shine-style color sequence and periodically sweeps it across the object.
Effects.shine = function(controller: InternalController)
	local gradient = controller.Gradient
	local options = controller.Options
	local startOffset = options.StartOffset or Vector2.new(-1, 0)
	local endOffset = options.EndOffset or Vector2.new(1, 0)
	local delayBetweenBursts = options.Delay or 2.5
	local shinesPerBurst = math.max(options.ShinesPerBurst or 2, 1)

	if defaultStyleEnabled(options) or options.BaseColor ~= nil or options.ShineColor ~= nil then
		local baseColor = options.BaseColor or Color3.fromRGB(255, 75, 170)
		local shineColor = options.ShineColor or Color3.fromRGB(255, 220, 245)

		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, baseColor),
			ColorSequenceKeypoint.new(0.5, shineColor),
			ColorSequenceKeypoint.new(1, baseColor),
		})
	end

	if options.Rotation ~= nil then
		gradient.Rotation = options.Rotation
	elseif defaultStyleEnabled(options) then
		gradient.Rotation = 45
	end

	gradient.Offset = startOffset

	local tweenInfo = makeTweenInfo(options, 1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, false)
	local tween = trackTween(
		controller,
		TweenService:Create(gradient, tweenInfo, {
			Offset = endOffset,
		})
	)

	task.spawn(function()
		while controller.Running do
			for _ = 1, shinesPerBurst do
				if not controller.Running then
					return
				end

				gradient.Offset = startOffset

				if not playAndWait(controller, tween) then
					return
				end
			end

			gradient.Offset = startOffset

			if not cancellableWait(controller, delayBetweenBursts) then
				return
			end
		end
	end)
end

-- Hover
-- Moves the gradient into view on hover and alternates the side it exits from.
Effects.hover = function(controller: InternalController)
	local gradient = controller.Gradient
	local target = controller.Target
	local options = controller.Options

	local guiTarget = assertGuiObject(target, controller.Effect)
	local startOffset = options.StartOffset or Vector2.new(-1, 0)

	if options.Colors ~= nil then
		gradient.Color = makeColorSequence(options.Colors)
	elseif defaultStyleEnabled(options) then
		gradient.Color = makeColorSequence({
			Color3.fromRGB(255, 230, 80),
			Color3.fromRGB(80, 255, 130),
			Color3.fromRGB(70, 180, 255),
		})
	end

	if options.Rotation ~= nil then
		gradient.Rotation = options.Rotation
	end

	gradient.Offset = startOffset

	local hoverInInfo = makeTweenInfo(options, 1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, false)
	-- Keep the same duration, but spread the exit movement across the tween.
	local hoverOutInfo = makeTweenInfo(options, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, false)
	local hoverInTween = trackTween(controller, TweenService:Create(gradient, hoverInInfo, { Offset = Vector2.zero }))
	local hoverOutLeftTween =
		trackTween(controller, TweenService:Create(gradient, hoverOutInfo, { Offset = Vector2.new(-1, 0) }))
	local hoverOutRightTween =
		trackTween(controller, TweenService:Create(gradient, hoverOutInfo, { Offset = Vector2.new(1, 0) }))
	local hoverCount = 1

	trackConnection(
		controller,
		guiTarget.MouseEnter:Connect(function()
			if not controller.Running then
				return
			end

			cancelOtherTweens(controller, hoverInTween)
			hoverInTween:Play()
		end)
	)

	trackConnection(
		controller,
		guiTarget.MouseLeave:Connect(function()
			if not controller.Running then
				return
			end

			local tween = if hoverCount % 2 == 0 then hoverOutLeftTween else hoverOutRightTween
			cancelOtherTweens(controller, tween)
			tween:Play()
			hoverCount += 1
		end)
	)
end

-- HoverStay
-- While hovered, continuously slides between two sides by flipping rotation.
Effects.hoverStay = function(controller: InternalController)
	local gradient = controller.Gradient
	local target = controller.Target
	local options = controller.Options

	local guiTarget = assertGuiObject(target, controller.Effect)
	local startOffset = options.StartOffset or Vector2.new(1, 0)
	local endOffset = options.EndOffset or Vector2.new(-1, 0)

	if options.Colors ~= nil then
		gradient.Color = makeColorSequence(options.Colors)
	elseif defaultStyleEnabled(options) then
		gradient.Color = makeColorSequence({
			Color3.fromRGB(255, 95, 150),
			Color3.fromRGB(95, 180, 255),
		})
	end

	local baseRotation = options.Rotation or gradient.Rotation
	gradient.Offset = startOffset
	gradient.Rotation = baseRotation

	local currentRotation = baseRotation
	local hovering = false
	local tweenInfo = makeTweenInfo(options, 2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, false)
	local tween = trackTween(controller, TweenService:Create(gradient, tweenInfo, { Offset = endOffset }))

	trackConnection(
		controller,
		guiTarget.MouseEnter:Connect(function()
			if not controller.Running then
				return
			end

			hovering = true
			tween:Play()
		end)
	)

	trackConnection(
		controller,
		guiTarget.MouseLeave:Connect(function()
			if not controller.Running then
				return
			end

			hovering = false
			tween:Pause()
		end)
	)

	trackConnection(
		controller,
		tween.Completed:Connect(function(state)
			if not controller.Running or state ~= Enum.PlaybackState.Completed or not hovering then
				return
			end

			currentRotation = if currentRotation == baseRotation then baseRotation + 180 else baseRotation
			gradient.Rotation = currentRotation
			gradient.Offset = startOffset
			tween:Play()
		end)
	)
end

-- Rainbow
-- Continuously cycles a generated HSV rainbow palette.
Effects.rainbow = function(controller: InternalController)
	runPaletteCycle(controller, buildRainbowColors(controller.Options))
end

-- Scroll / Flow
-- Continuously moves the existing gradient from StartOffset to EndOffset.
Effects.scroll = function(controller: InternalController)
	local gradient = controller.Gradient
	local options = controller.Options
	local startOffset = options.StartOffset or Vector2.new(-1, 0)
	local endOffset = options.EndOffset or Vector2.new(1, 0)

	if options.Colors then
		gradient.Color = makeColorSequence(options.Colors)
	end

	if options.Rotation ~= nil then
		gradient.Rotation = options.Rotation
	end

	gradient.Offset = startOffset

	local tweenInfo = makeTweenInfo(options, 2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, false)
	local tween = trackTween(controller, TweenService:Create(gradient, tweenInfo, { Offset = endOffset }))

	task.spawn(function()
		while controller.Running do
			gradient.Offset = startOffset

			if not playAndWait(controller, tween) then
				return
			end
		end
	end)
end

-- Rotate
-- Continuously rotates the gradient while preserving its current colors and offset.
Effects.rotate = function(controller: InternalController)
	local gradient = controller.Gradient
	local options = controller.Options
	local startRotation = options.StartRotation or options.Rotation or gradient.Rotation
	local direction = if options.Clockwise == false then -1 else 1
	local degrees = math.abs(options.Degrees or 360) * direction

	gradient.Rotation = startRotation

	local tweenInfo = makeTweenInfo(options, 4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, false)
	local tween = trackTween(
		controller,
		TweenService:Create(gradient, tweenInfo, {
			Rotation = startRotation + degrees,
		})
	)

	task.spawn(function()
		while controller.Running do
			gradient.Rotation = startRotation

			if not playAndWait(controller, tween) then
				return
			end
		end
	end)
end

-- Sweep
-- Periodically sweeps the existing gradient across the object without imposing a color style.
Effects.sweep = function(controller: InternalController)
	local gradient = controller.Gradient
	local options = controller.Options
	local startOffset = options.StartOffset or Vector2.new(-1, 0)
	local endOffset = options.EndOffset or Vector2.new(1, 0)
	local delayBetweenSweeps = options.Delay or 1.5

	if options.Colors then
		gradient.Color = makeColorSequence(options.Colors)
	end

	if options.Rotation ~= nil then
		gradient.Rotation = options.Rotation
	end

	gradient.Offset = startOffset

	local tweenInfo = makeTweenInfo(options, 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, false)
	local tween = trackTween(controller, TweenService:Create(gradient, tweenInfo, { Offset = endOffset }))

	task.spawn(function()
		while controller.Running do
			gradient.Offset = startOffset

			if not playAndWait(controller, tween) then
				return
			end

			gradient.Offset = startOffset

			if not cancellableWait(controller, delayBetweenSweeps) then
				return
			end
		end
	end)
end

-- Pressed / Activated
-- Moves the gradient to a pressed state for mouse/touch input, then returns to rest.
Effects.pressed = function(controller: InternalController)
	local gradient = controller.Gradient
	local target = controller.Target
	local options = controller.Options

	local guiTarget = assertGuiObject(target, controller.Effect)
	local restOffset = options.RestOffset or options.StartOffset or gradient.Offset
	local pressedOffset = options.PressedOffset or options.EndOffset or Vector2.new(0.12, 0)
	local restRotation = options.RestRotation or options.Rotation or gradient.Rotation
	local pressedRotation = options.PressedRotation or restRotation

	if options.Colors then
		gradient.Color = makeColorSequence(options.Colors)
	end

	gradient.Offset = restOffset
	gradient.Rotation = restRotation

	local tweenInfo = makeTweenInfo(options, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, false)
	local pressTween = trackTween(
		controller,
		TweenService:Create(gradient, tweenInfo, {
			Offset = pressedOffset,
			Rotation = pressedRotation,
		})
	)
	local releaseTween = trackTween(
		controller,
		TweenService:Create(gradient, tweenInfo, {
			Offset = restOffset,
			Rotation = restRotation,
		})
	)

	local function isPressInput(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end

	trackConnection(
		controller,
		guiTarget.InputBegan:Connect(function(input)
			if not controller.Running or not isPressInput(input) then
				return
			end

			cancelOtherTweens(controller, pressTween)
			pressTween:Play()
		end)
	)

	trackConnection(
		controller,
		guiTarget.InputEnded:Connect(function(input)
			if not controller.Running or not isPressInput(input) then
				return
			end

			cancelOtherTweens(controller, releaseTween)
			releaseTween:Play()
		end)
	)
end

-- ColorCycle
-- Continuously cycles across a supplied palette of 3+ colors.
Effects.colorCycle = function(controller: InternalController)
	runPaletteCycle(controller, resolveCycleColors(controller.Options))
end

local function resolveInteractionTarget(gradient: UIGradient, options: EffectOptions): GuiObject?
	if options.InteractionTarget ~= nil then
		return options.InteractionTarget
	end

	local parent = gradient.Parent
	if parent and parent:IsA("GuiObject") then
		return parent
	end

	return nil
end

local function cleanupController(controller: InternalController, restore: boolean)
	if not controller.Running and Active[controller.Gradient] ~= controller then
		return
	end

	controller.Running = false

	for _, connection in ipairs(controller.Connections) do
		connection:Disconnect()
	end
	table.clear(controller.Connections)

	for _, tween in ipairs(controller.Tweens) do
		tween:Cancel()
	end
	table.clear(controller.Tweens)

	if restore and controller.Gradient.Parent ~= nil then
		controller.Gradient.Enabled = controller.Initial.Enabled
		controller.Gradient.Color = controller.Initial.Color
		controller.Gradient.Transparency = controller.Initial.Transparency
		controller.Gradient.Offset = controller.Initial.Offset
		controller.Gradient.Rotation = controller.Initial.Rotation
	end

	if Active[controller.Gradient] == controller then
		Active[controller.Gradient] = nil
	end

	if controller.Options.DestroyOnStop == true and controller.OwnsGradient and controller.Gradient.Parent ~= nil then
		controller.Gradient:Destroy()
	end
end

function GradientKit.Create(guiObject: GuiObject, properties: GradientProperties?): UIGradient
	assert(guiObject:IsA("GuiObject"), "GradientKit.Create expected a GuiObject.")

	local props: GradientProperties = properties or {}
	local gradient = Instance.new("UIGradient")
	gradient.Name = props.Name or "Gradient"

	if props.Enabled ~= nil then
		gradient.Enabled = props.Enabled
	end

	if props.Color ~= nil then
		gradient.Color = props.Color
	elseif props.Colors ~= nil then
		gradient.Color = makeColorSequence(props.Colors)
	end

	if props.Transparency ~= nil then
		gradient.Transparency = props.Transparency
	end

	if props.Offset ~= nil then
		gradient.Offset = props.Offset
	end

	if props.Rotation ~= nil then
		gradient.Rotation = props.Rotation
	end

	gradient.Parent = guiObject
	return gradient
end

function GradientKit.Start(gradient: UIGradient, effectName: EffectName | string, options: EffectOptions?): Controller
	assertGradient(gradient)
	local effectOptions: EffectOptions = options or {}
	local normalizedEffectName = normalizeEffectName(effectName)

	assert(
		normalizedEffectName and Effects[normalizedEffectName],
		string.format("Unknown gradient effect %q. Supported effects: %s", tostring(effectName), SUPPORTED_EFFECTS)
	)

	GradientKit.Stop(gradient)

	local controller: InternalController = {
		__gradientKitController = true,
		Gradient = gradient,
		Target = resolveInteractionTarget(gradient, effectOptions),
		Effect = normalizedEffectName :: string,
		Options = effectOptions,
		Running = true,
		OwnsGradient = false,
		Tweens = {},
		Connections = {},
		Initial = {
			Enabled = gradient.Enabled,
			Color = gradient.Color,
			Transparency = gradient.Transparency,
			Offset = gradient.Offset,
			Rotation = gradient.Rotation,
		},
		Stop = function(self: Controller): boolean
			return GradientKit.Stop(self)
		end,
		IsRunning = function(self: Controller): boolean
			return self.Running
		end,
	}

	Active[gradient] = controller

	trackConnection(
		controller,
		gradient.Destroying:Connect(function()
			cleanupController(controller, false)
		end)
	)

	local success, result = pcall(function()
		Effects[normalizedEffectName :: string](controller)
	end)

	if not success then
		cleanupController(controller, effectOptions.RestoreOnStop ~= false)
		error(result, 2)
	end

	return controller
end

function GradientKit.Apply(guiObject: GuiObject, effectName: EffectName | string, options: EffectOptions?): Controller
	assert(guiObject:IsA("GuiObject"), "GradientKit.Apply expected a GuiObject.")
	local effectOptions = table.clone(options or {}) :: EffectOptions
	local gradientName = effectOptions.GradientName
	local gradient: UIGradient? = nil

	if gradientName ~= nil then
		local named = guiObject:FindFirstChild(gradientName)
		if named and named:IsA("UIGradient") then
			gradient = named
		end
	else
		local existing = guiObject:FindFirstChildOfClass("UIGradient")
		if existing then
			gradient = existing
		end
	end

	local ownsGradient = false
	if gradient == nil then
		gradient = GradientKit.Create(guiObject, {
			Name = gradientName or "Gradient",
		})
		ownsGradient = true
	end

	if effectOptions.InteractionTarget == nil then
		effectOptions.InteractionTarget = guiObject
	end

	assert(gradient ~= nil, "GradientKit failed to resolve or create a gradient.")
	local controller = GradientKit.Start(gradient, effectName, effectOptions)
	local internalController = Active[gradient]
	assert(internalController ~= nil, "GradientKit failed to create an active controller.")
	internalController.OwnsGradient = ownsGradient
	return controller
end

function GradientKit.Stop(target: UIGradient | Controller?): boolean
	if target == nil then
		return GradientKit.StopAll() > 0
	end

	local controller: InternalController? = nil

	if typeof(target) == "Instance" then
		if target:IsA("UIGradient") then
			controller = Active[target]
		end
	elseif type(target) == "table" and (target :: any).__gradientKitController then
		controller = target :: InternalController
	end

	if not controller then
		return false
	end

	cleanupController(controller, controller.Options.RestoreOnStop ~= false)
	return true
end

function GradientKit.StopAll(): number
	local controllers: { InternalController } = {}

	for _, controller in pairs(Active) do
		table.insert(controllers, controller)
	end

	for _, controller in ipairs(controllers) do
		cleanupController(controller, controller.Options.RestoreOnStop ~= false)
	end

	return #controllers
end

function GradientKit.IsActive(gradient: UIGradient): boolean
	return Active[gradient] ~= nil
end

function GradientKit.GetController(gradient: UIGradient): Controller?
	return Active[gradient]
end

return GradientKit
