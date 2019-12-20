# ref
# https://github.com/JuliaDebug/Debugger.jl/blob/c01f25c14317e6b8a4e72cab8418d6112465a369/src/repl.jl

using Yao, YaoBlocks, MLStyle
using REPL, REPL.LineEdit

export yaorepl

include("parse.jl")

function yaorepl(repl = nothing, terminal = nothing)
    if repl === nothing
        if !isdefined(Base, :active_repl)
            error("Debugger.jl needs to be run in a Julia REPL")
        end
        repl = Base.active_repl
    end
    if !isa(repl, REPL.LineEditREPL)
        error("Debugger.jl requires a LineEditREPL type of REPL")
    end

    if terminal === nothing
        terminal = Base.active_repl.t
    end
    state = YaoREPLState()

    normal_prefix = Sys.iswindows() ? "\e[33m" : "\e[38;5;166m"
    panel = LineEdit.Prompt("yao> ";
        prompt_prefix = () -> normal_prefix,
        prompt_suffix = Base.text_colors[:normal],
        on_enter = s->true)

    panel.hist = REPL.REPLHistoryProvider(Dict{Symbol,Any}(:debug => panel))
    REPL.history_reset_state(panel.hist)

    search_prompt, skeymap = LineEdit.setup_search_keymap(panel.hist)
    search_prompt.complete = REPL.LatexCompletions()
    standard_keymap = Dict{Any,Any}[skeymap, LineEdit.history_keymap, LineEdit.default_keymap, LineEdit.escape_defaults]
    panel.keymap_dict = LineEdit.keymap(standard_keymap)

    panel.on_done = (s,buf,ok)->begin
        line = String(take!(buf))
        if !ok || strip(line) == "q"
            LineEdit.transition(s, :abort)
            LineEdit.reset_state(s)
            return false
        end
        if isempty(strip(line))
            command = panel.hist.history[end]
        else
            command = strip(line)
        end
        do_print_status = true
        cmd1 = split(command,' ')[1]
        try
            msg = yaorepl_handler(command, state)
            if msg isa AbstractString
                println(msg)
            end
        catch err
            Base.display_error(err)
            LineEdit.reset_state(s)
        end
        LineEdit.reset_state(s)
        return true
    end

    REPL.run_interface(terminal, LineEdit.ModalInterface([panel,search_prompt]))
    return state
end

function yaorepl_handler(str::AbstractString, state)
    if length(strip(str)) >=2 && strip(str)[1:2] == "c "
        string(yaorepl_trans(yaorepl_parse(str[3:end]), state))
    else
        yaorepl_execute(yaorepl_trans(yaorepl_parse(str), state), state)
    end
end
