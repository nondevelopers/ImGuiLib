# xqzMenu

## Installation
```lua
-- Boot
local ImGuiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xqzxa/xqzMenu/main/source.lua"))()

-- Create Window
local Window = ImGuiLib:CreateWindow({
    Title = "UI Library Template",
    Size = Vector2.new(340, 430)
})

-- Create Section Header
local Section = Window:CreateHeader({ Name = "Section Header" })

-- Create Toggle
Section:CreateToggle({
    Name = "Toggle",
    Default = false,
    Callback = function(state)
        print(state)
    end
})

-- Create Slider
Section:CreateSlider({
    Name = "Slider",
    Min = 0,
    Max = 100,
    Default = 50,
    Callback = function(val)
        print(val)
    end
})

-- Create Dropdown
Section:CreateDropdown({
    Name = "Dropdown",
    Options = {"Option 1", "Option 2", "Option 3"},
    Default = "Option 1",
    Callback = function(selection)
        print(selection)
    end
})

-- Create TextBox
Section:CreateTextBox({
    Name = "TextBox",
    Placeholder = "Type here...",
    Callback = function(inputStr)
        print(inputStr)
    end
})

-- Create Keybind
Section:CreateKeybind({
    Name = "Keybind",
    Default = Enum.KeyCode.E,
    Callback = function()
        print("Activated")
    end
})

-- Create Multi Dropdown
Section:CreateMultiDropdown({
    Name = "Multi Dropdown",
    Options = {"Option 1", "Option 2", "Option 3", "Option 4"},
    Default = {["Option 1"] = true},
    Callback = function(selections)
        for option, checked in pairs(selections) do
            print(option, checked)
        end
    end
})

-- Create Paragraph
local Paragraph = Section:CreateParagraph({
    Text = "This is a Paragraph element.",
    Color = Color3.fromRGB(170, 180, 190)
})

