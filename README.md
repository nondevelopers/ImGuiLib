# ImGuiLib
Ui liberay for roblox, made with claude ai.

## Installation
```luau
-- Boot
local ImGuiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/nondevelopers/ImGuiLib/main/source.luau"))()

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
-- (Supports two configurations for the Mode argument: "Toggle" or "Hold")
Section:CreateKeybind({
    Name = "Keybind",
    Default = Enum.KeyCode.E,
    Mode = "Toggle", 
    Callback = function(state)
        print("Keybind active:", state)
    end
})

-- Create Paragraph
local Paragraph = Section:CreateParagraph({
    Text = "This is a Paragraph element.",
    Color = Color3.fromRGB(170, 180, 190)
})

-- Create Button
Section:CreateButton({
    Name = "Button Name Here",
    Callback = function()
        print("Button clicked!")
        -- Put your script features or actions here
    end
})

-- Create Label
local Label = Section:CreateLabel({
    Text = "This is a Label element.",
    Color = Color3.fromRGB(180, 180, 180) -- optional
})
-- Update the label text and color at any time:
Label:SetText("Updated text!")
Label:SetColor(Color3.fromRGB(255, 80, 80))

-- Notify
-- (Color controls the accent bar and progress bar color)
ImGuiLib:Notify({
    Title = "Notification Title",
    Message = "This is the notification message.",
    Duration = 3,                            -- optional, default 3
    Color = Color3.fromRGB(30, 120, 215)     -- optional
})

