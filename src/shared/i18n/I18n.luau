--!strict

local LocalizationService = game:GetService("LocalizationService")

local en = require(script.Parent.en)
local ru = require(script.Parent.ru)

export type Language = "en" | "ru"

local dictionaries: { [Language]: { [string]: string } } = {
	en = en,
	ru = ru,
}

local function startsWithRu(locale: string): boolean
	return string.sub(string.lower(locale), 1, 2) == "ru"
end

local function detectInitialLanguage(): Language
	local sysOk, sysLocale = pcall(function(): string
		return LocalizationService.SystemLocaleId
	end)
	local rbxOk, rbxLocale = pcall(function(): string
		return LocalizationService.RobloxLocaleId
	end)

	local systemLocaleId = if sysOk and type(sysLocale) == "string" then sysLocale else ""
	local robloxLocaleId = if rbxOk and type(rbxLocale) == "string" then rbxLocale else ""

	if startsWithRu(systemLocaleId) or startsWithRu(robloxLocaleId) then
		return "ru"
	end

	return "en"
end

local currentLanguage: Language = detectInitialLanguage()
local onLanguageChangedEvent = Instance.new("BindableEvent")
onLanguageChangedEvent.Name = "OnLanguageChanged"

local I18n = {}

I18n.OnLanguageChanged = onLanguageChangedEvent

function I18n.GetLanguage(): Language
	return currentLanguage
end

function I18n.SetLanguage(lang: Language)
	if lang ~= "en" and lang ~= "ru" then
		return
	end
	if currentLanguage ~= lang then
		currentLanguage = lang
		onLanguageChangedEvent:Fire(currentLanguage)
	end
end

function I18n.t(key: string, params: { [string]: string | number }?, overrideLang: Language?): string
	local targetLang: Language = overrideLang or currentLanguage
	local dict = dictionaries[targetLang] or dictionaries.en
	local template = dict[key] or dictionaries.en[key] or key

	if params then
		local formatted = string.gsub(template, "{([%w_]+)}", function(placeholder: string): string
			local val = params[placeholder]
			if val ~= nil then
				return tostring(val)
			end
			return "{" .. placeholder .. "}"
		end)
		return formatted
	end

	return template
end

return I18n
