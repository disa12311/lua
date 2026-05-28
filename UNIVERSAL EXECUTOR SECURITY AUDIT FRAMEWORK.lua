--// =========================================================
--// UNIVERSAL EXECUTOR SECURITY AUDIT FRAMEWORK
--// Optimized Multi-Executor Edition
--// Diagnostic / Research Only
--// =========================================================

local Framework = {
    Results = {},
    Cache = {},
    StartTime = os.clock()
}

--// =========================================================
--// SAFE COMPATIBILITY LAYER
--// =========================================================

local env = (getgenv and getgenv())
    or (getfenv and getfenv())
    or _G

local function rawGlobal(name)
    local ok, result = pcall(function()
        return rawget(env, name)
    end)

    return ok and result or nil
end

local Compat = {

    identifyexecutor =
        rawGlobal("identifyexecutor"),

    getgenv =
        rawGlobal("getgenv"),

    getrenv =
        rawGlobal("getrenv"),

    getsenv =
        rawGlobal("getsenv"),

    getmenv =
        rawGlobal("getmenv"),

    getrawmetatable =
        rawGlobal("getrawmetatable"),

    setreadonly =
        rawGlobal("setreadonly"),

    isreadonly =
        rawGlobal("isreadonly"),

    hookfunction =
        rawGlobal("hookfunction"),

    hookmetamethod =
        rawGlobal("hookmetamethod"),

    newcclosure =
        rawGlobal("newcclosure"),

    clonefunction =
        rawGlobal("clonefunction"),

    iscclosure =
        rawGlobal("iscclosure"),

    islclosure =
        rawGlobal("islclosure"),

    getthreadidentity =
        rawGlobal("getthreadidentity"),

    setthreadidentity =
        rawGlobal("setthreadidentity"),

    request =
        rawGlobal("request")
        or rawGlobal("http_request")
        or (
            rawGlobal("syn")
            and rawGlobal("syn").request
        ),

    writefile =
        rawGlobal("writefile"),

    readfile =
        rawGlobal("readfile"),

    delfile =
        rawGlobal("delfile"),

    listfiles =
        rawGlobal("listfiles"),

    debug =
        rawGlobal("debug"),

    Drawing =
        rawGlobal("Drawing")
}

--// =========================================================
--// UTIL
--// =========================================================

local function push(category, name, severity, success, result)

    Framework.Results[#Framework.Results + 1] = {

        Category = category,
        Name = name,
        Severity = severity,
        Success = success,
        Result = result
    }
end

local function safe(category, name, severity, fn)

    local ok, result = pcall(fn)

    push(
        category,
        name,
        severity,
        ok,
        ok and result or tostring(result)
    )

    return ok, result
end

local function fastType(v)

    local ok, t = pcall(typeof, v)

    return ok and t or type(v)
end

local function safeDebugInfo(fn)

    if fastType(fn) ~= "function" then
        return nil
    end

    if not Compat.debug then
        return nil
    end

    local getinfo =
        Compat.debug.getinfo

    if not getinfo then
        return nil
    end

    local ok, info =
        pcall(getinfo, fn)

    if not ok or not info then
        return nil
    end

    return {

        What = info.what,
        Source = info.source,
        Name = info.name,
        Nups = info.nups
    }
end

--// =========================================================
--// EXECUTOR DETECTION
--// =========================================================

safe(
    "Environment",
    "Executor",
    "Info",

    function()

        if Compat.identifyexecutor then

            local ok, name =
                pcall(Compat.identifyexecutor)

            if ok then
                return name
            end
        end

        return "Unknown"
    end
)

--// =========================================================
--// UNIVERSAL API EXPOSURE SCAN
--// =========================================================

local APIs = {

    --// Environment
    "getgenv",
    "getrenv",
    "getsenv",
    "getmenv",

    --// Metatable
    "getrawmetatable",
    "setreadonly",
    "isreadonly",

    --// Hooking
    "hookfunction",
    "hookmetamethod",
    "newcclosure",
    "clonefunction",

    --// Threading
    "getthreadidentity",
    "setthreadidentity",

    --// Filesystem
    "writefile",
    "readfile",
    "delfile",
    "listfiles",

    --// Drawing
    "Drawing",

    --// Network
    "request",

    --// Debug
    "debug"
}

for i = 1, #APIs do

    local api = APIs[i]

    safe(
        "APIExposure",
        api,
        "Info",

        function()

            local value = Compat[api]

            if value == nil then

                return {
                    Exposed = false
                }
            end

            return {

                Exposed = true,
                Type = fastType(value),
                DebugInfo =
                    fastType(value) == "function"
                    and safeDebugInfo(value)
                    or nil
            }
        end
    )
end

--// =========================================================
--// METATABLE AUDIT
--// =========================================================

safe(
    "Metatable",
    "__namecall",
    "High",

    function()

        if not Compat.getrawmetatable then
            return "Unsupported"
        end

        local mt =
            Compat.getrawmetatable(game)

        if not mt then
            return "Failed"
        end

        local nc =
            rawget(mt, "__namecall")

        return {

            Exists = nc ~= nil,

            Readonly =
                Compat.isreadonly
                and Compat.isreadonly(mt)
                or "Unknown",

            Type = fastType(nc),

            DebugInfo =
                safeDebugInfo(nc)
        }
    end
)

--// =========================================================
--// FUNCTION INTEGRITY
--// =========================================================

local integrityTargets = {

    {
        Name = "game.GetService",
        Fn = game.GetService
    },

    {
        Name = "Instance.new",
        Fn = Instance.new
    },

    {
        Name = "task.wait",
        Fn = task.wait
    }
}

for i = 1, #integrityTargets do

    local target =
        integrityTargets[i]

    safe(
        "Integrity",
        target.Name,
        "Medium",

        function()

            local before =
                tostring(target.Fn)

            task.wait()

            local after =
                tostring(target.Fn)

            return {

                Stable =
                    before == after,

                Before = before,
                After = after
            }
        end
    )
end

--// =========================================================
--// FILESYSTEM TEST
--// =========================================================

safe(
    "Filesystem",
    "Sandbox",
    "High",

    function()

        if not Compat.writefile
        or not Compat.readfile then

            return "Unavailable"
        end

        local file =
            "audit_test.txt"

        Compat.writefile(
            file,
            "test"
        )

        local content =
            Compat.readfile(file)

        if Compat.delfile then
            pcall(
                Compat.delfile,
                file
            )
        end

        return {

            Readback =
                content == "test",

            DeleteSupported =
                Compat.delfile ~= nil
        }
    end
)

--// =========================================================
--// HTTP TEST
--// =========================================================

safe(
    "Network",
    "HTTP API",
    "Medium",

    function()

        if not Compat.request then
            return "Unavailable"
        end

        return {

            Exists = true,
            Type = fastType(Compat.request)
        }
    end
)

--// =========================================================
--// THREAD INSPECTOR
--// =========================================================

safe(
    "Threading",
    "Identity",
    "Medium",

    function()

        if not Compat.getthreadidentity then
            return "Unsupported"
        end

        return Compat.getthreadidentity()
    end
)

--// =========================================================
--// PERFORMANCE BENCH
--// =========================================================

safe(
    "Performance",
    "Coroutine Stress",
    "Low",

    function()

        local start =
            os.clock()

        for i = 1, 2000 do

            coroutine.wrap(function()
                local _ = i * 2
            end)()
        end

        return os.clock() - start
    end
)

safe(
    "Performance",
    "Memory",
    "Low",

    function()

        if gcinfo then
            return gcinfo()
        end

        return "Unsupported"
    end
)

--// =========================================================
--// DETECTION SURFACE
--// =========================================================

safe(
    "Detection",
    "Global Fingerprints",
    "Medium",

    function()

        local suspicious = {}

        for k in pairs(env) do

            local lower =
                tostring(k):lower()

            if lower:find("syn")
            or lower:find("flux")
            or lower:find("krnl")
            or lower:find("electron")
            or lower:find("solara")
            then

                suspicious[
                    #suspicious + 1
                ] = k
            end
        end

        return suspicious
    end
)

--// =========================================================
--// SCORE SYSTEM
--// =========================================================

safe(
    "Analysis",
    "Security Score",
    "Info",

    function()

        local passed = 0

        for i = 1, #Framework.Results do

            if Framework.Results[i].Success then
                passed += 1
            end
        end

        return {

            Passed = passed,
            Total = #Framework.Results,

            Percent = math.floor(
                (passed / #Framework.Results) * 100
            ),

            Runtime = os.clock()
                - Framework.StartTime
        }
    end
)

--// =========================================================
--// OUTPUT
--// =========================================================

print("")
print("===================================")
print("UNIVERSAL EXECUTOR SECURITY AUDIT")
print("===================================")

for i = 1, #Framework.Results do

    local r =
        Framework.Results[i]

    print("")

    print(
        string.format(
            "[%s] [%s] %s",
            r.Severity,
            r.Category,
            r.Name
        )
    )

    print(r.Result)
end

print("")
print("===================================")
print("SCAN COMPLETE")
print("===================================")

return Framework
