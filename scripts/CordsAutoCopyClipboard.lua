local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    
    if input.KeyCode == Enum.KeyCode.V then
        local Character = LocalPlayer.Character
        if Character and Character:FindFirstChild("HumanoidRootPart") then
            local pos = Character.HumanoidRootPart.Position
            local formattedCords = string.format("Vector3.new(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z)
            
            local setClip = setclipboard or toclipboard
            if setClip then
                setClip(formattedCords)

                StarterGui:SetCore("SendNotification", {
                    Title = "Coordinates Copied",
                    Text = formattedCords,
                    Duration = 2
                })
            end
        end
    end
end)
