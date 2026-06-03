# xqzMenu

## Installation
```lua
local ImGuiLib = loadstring(game:HttpGet("[https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/source.lua](https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/source.lua)"))()

## Create Window
```lua
local Window = ImGuiLib:CreateWindow({
    Title = "UI Library Template",
    Size = Vector2.new(340, 430)
})```

## Create Section Header
```lua
local Section = Window:CreateHeader({ Name = "Section Header" })```

## Create Toggle
```lua
Section:CreateToggle({
    Name = "Toggle",
    Default = false,
    Callback = function(state)
        print(state)
    end
})```

## Create Slider
```lua
Section:CreateSlider({
    Name = "Slider",
    Min = 0,
    Max = 100,
    Default = 50,
    Callback = function(val)
        print(val)
    end
})
