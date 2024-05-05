-- made by RenKa (@RenKaDi)
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local packages = script.Packages

local waitFor = require(packages.WaitFor)
local trove = require(packages.Trove)

local characterMovements = {
	currentPlayers = {}
}

local camera = workspace.CurrentCamera

local EMPTY_CFRAME = CFrame.new()

local function humanoidNotOnState(humanoid: Humanoid, state: string)
	return humanoid:GetState() ~= Enum.HumanoidStateType[state]
end

local function onNewPlayer(player: Player)
	characterMovements.currentPlayers[player] = {
		_obj = player,
		trove = trove.new(),
		Character = player.Character or player.CharacterAdded:Wait(),
		RootTilt = EMPTY_CFRAME,
		CharacterSpeed = 0,
		Rendered = false
	}

	local index = characterMovements.currentPlayers[player]
	index.CharacterTrove = index.trove:Extend()

	local function onNewCharacter(character: Model)
		index.Character = character

		index.CharacterTrove:Clean()

		waitFor.Descendants(character, {
			"HumanoidRootPart",
			"RootJoint",
			"Humanoid",
			"Torso",
			"Left Hip",
			"Right Hip"
		}):andThen(function(desdendants: {[number]: Instance})
			index.RootPart, index.RootJoint, index.Humanoid, index.Torso, index.leftHipJoint, index.rightHipJoint = table.unpack(desdendants)
			index.leftHipC0 = index.leftHipJoint.C0
			index.rightHipC0 = index.rightHipJoint.C0
			index.OriginalRootJointC0 = index.RootJoint.C0

			index.CharacterTrove:Connect(index.Humanoid.Running, function(speed: number)
				index.CharacterSpeed = speed
			end)
		end)
	end

	if player.Character then
		onNewCharacter(player.Character)
	end

	index.trove:Connect(index._obj.CharacterAdded, onNewCharacter)

	index.trove:Connect(index._obj.Destroying, function()
		index.trove:Destroy()
		characterMovements.currentPlayers[player] = nil
	end)
end

for _, player in players:GetPlayers() do
	task.spawn(onNewPlayer, player)
end

players.PlayerAdded:Connect(onNewPlayer)

runService.PostSimulation:Connect(function(deltaTimeSim: number)
	local newDt: number = deltaTimeSim * 60

	for _, objects in characterMovements.currentPlayers do
		if objects.Humanoid then
			local _, onScreen = camera:WorldToScreenPoint(objects.RootPart.Position)
			objects.Rendered = onScreen

			if onScreen then
				local isHumanoidAlive: boolean = humanoidNotOnState(objects.Humanoid, "Dead")
				local moveDirection: Vector3 = isHumanoidAlive and objects.RootPart.CFrame:VectorToObjectSpace(objects.Humanoid.MoveDirection) or Vector3.zero
				local maxTilt: number = isHumanoidAlive and objects.CharacterSpeed / 2 or 0

				local normalizedVel = objects.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)

				local tiltZ, direction = 0, Vector3.new()
				if normalizedVel.magnitude > 2 then
					direction = normalizedVel.unit
					tiltZ = objects.RootPart.CFrame.RightVector:Dot(direction)
				end

                local leftHipTiltY = objects.Humanoid.MoveDirection:Dot(objects.RootPart.CFrame.LookVector) > -0.1 and math.rad(-tiltZ * 40)
                    or math.rad(tiltZ * 40)

				local lerpAlpha = normalizedVel.magnitude > 3 and 0.08 or 0.35
				objects.leftHipJoint.C0 = objects.leftHipJoint.C0:Lerp((objects.leftHipC0) * CFrame.Angles(0, leftHipTiltY, 0), lerpAlpha * newDt)
				objects.rightHipJoint.C0 = objects.rightHipJoint.C0:Lerp((objects.rightHipC0) * CFrame.Angles(0, leftHipTiltY, 0), lerpAlpha * newDt)

				objects.RootTilt = objects.RootTilt:Lerp(CFrame.Angles(0, math.rad(-moveDirection.X) * maxTilt, 0), 0.1 * newDt)
				objects.RootJoint.C0 = objects.OriginalRootJointC0 * (isHumanoidAlive and objects.RootTilt or EMPTY_CFRAME)
			end
		end
	end
end)

return characterMovements
