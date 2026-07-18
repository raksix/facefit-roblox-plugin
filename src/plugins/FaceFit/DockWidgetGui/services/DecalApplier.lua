--!strict
-- DecalApplier — applies an uploaded face texture as a Decal to the target Head.

local DecalApplier = {}

export type HeadType = "R6" | "R15"
export type ApplyMode = "replace" | "new"

function DecalApplier.apply(
	targetHead: BasePart,
	assetId: string,
	headType: HeadType,
	mode: ApplyMode
): Decal
	assert(typeof(targetHead) == "Instance" and targetHead:IsA("BasePart"), "targetHead must be a BasePart")
	assert(targetHead.Name == "Head", "target must be named 'Head' (got: " .. targetHead.Name .. ")")
	assert(typeof(assetId) == "string" and assetId ~= "", "assetId must be non-empty string")

	-- Handle existing decals
	for _, child in targetHead:GetChildren() do
		if child:IsA("Decal") and child.Name:match("^FaceFit") then
			if mode == "replace" then
				child:Destroy()
			end
		end
	end

	local decal = Instance.new("Decal")
	decal.Name = "FaceFit_" .. os.time()
	decal.Texture = "rbxassetid://" .. assetId

	if headType == "R6" then
		decal.Face = Enum.NormalId.Front
		decal.Parent = targetHead
	else
		-- R15: parent to FaceCenterAttachment if available, else fallback to Front face
		local attachment = targetHead:FindFirstChild("FaceCenterAttachment")
		if attachment and attachment:IsA("Attachment") then
			decal.Parent = attachment
		else
			decal.Face = Enum.NormalId.Front
			decal.Parent = targetHead
		end
	end

	return decal
end

-- Reads current Selection and validates it is a Head. Returns nil if not.
function DecalApplier.getSelectedHead(): BasePart?
	local selected = Selection:Get()
	for _, item in selected do
		if typeof(item) == "Instance" and item:IsA("BasePart") and item.Name == "Head" then
			return item
		end
	end
	return nil
end

return DecalApplier
