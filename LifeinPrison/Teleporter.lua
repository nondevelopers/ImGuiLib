local ImGuiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xqzxa/xqzMenu/main/source.lua"))()
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Locations = {
    { Name = "Main Hall", Cords = Vector3.new(104.38, 1075.14, 60.65) },
    { Name = "Cafetaria", Cords = Vector3.new(130.32, 1075.92, -2.81) },
    { Name = "Cell Block", Cords = Vector3.new(106.97, 1073.39, 145.38) },
    { Name = "Yard", Cords = Vector3.new(-54.37, 1075.06, 237.34) },
    { Name = "Armory", Cords = Vector3.new(-37.97, 1083.43, 3.13) },
    { Name = "Prison Roof", Cords = Vector3.new(-9.69, 1119.88, 16.96) },
    { Name = "Front Gate", Cords = Vector3.new(-303.54, 1072.76, -6.10) },
    { Name = "WareHouse (Criminal base 1)", Cords = Vector3.new(-1451.65, 1083.61, 93.37)},
    { Name = "WareHouse Roof", Cords = Vector3.new(-1428.42, 1111.33, 80.17)},
    { Name = "Outpost (Criminal base 2)", Cords = Vector3.new(-650.52, 1054.74, -635.37)},
    { Name = "Outpost Roof", Cords = Vector3.new(-658.18, 1090.99, -634.69)},
    { Name = "Arms Store", Cords = Vector3.new(-1005.82, 1049.43, 170.54)},
    { Name = "Barn", Cords = Vector3.new(-1017.38, 1076.87, 397.64)},
    { Name = "China House thing", Cords = Vector3.new(-994.29, 1084.72, -198.58)},
    { Name = "Special Guns", Cords = Vector3.new(-137.43, 1197.38, -738.71)},
    { Name = "Factory", Cords = Vector3.new(-1153.58, 1061.36, -97.44)}
}

local LocationNames = {}
local CordsLookup = {}

for _, data in ipairs(Locations) do
    table.insert(LocationNames, data.Name)
    CordsLookup[data.Name] = data.Cords
end

local Window = ImGuiLib:CreateWindow({
    Title = "Life in Prison Teleport Tool",
    Size = Vector2.new(340, 260)
})

local MainSection = Window:CreateHeader({ Name = "Movement Matrix" })

local StatusLog = MainSection:CreateParagraph({
    Text = "Status: Ready",
    Color = Color3.fromRGB(140, 220, 140)
})

local function Teleport(targetName)
    local Character = LocalPlayer.Character
    if Character and Character:FindFirstChild("HumanoidRootPart") then
        local targetCords = CordsLookup[targetName]
        if targetCords then
            local hrp = Character.HumanoidRootPart
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            hrp.CFrame = CFrame.new(targetCords)
            StatusLog:SetText("Status: Teleported to " .. targetName)
        end
    else
        StatusLog:SetText("Status: Error - Character not found")
    end
end

MainSection:CreateDropdown({
    Name = "Place Teleportion",
    Options = LocationNames,
    Default = LocationNames[1] or "None",
    Callback = function(selection)
        Teleport(selection)
    end
})
