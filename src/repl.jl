# ref
# https://github.com/JuliaDebug/Debugger.jl/blob/c01f25c14317e6b8a4e72cab8418d6112465a369/src/repl.jl

struct YaoREPLState
    frame
    vars::Dict
end
function run_yaorepl(frame, repl = nothing, terminal = nothing; initial_continue=false)
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
    state = Dict{Symbol,Any}()

    # Setup debug panel
    normal_prefix = Sys.iswindows() ? "\e[33m" : "\e[38;5;166m"
    panel = LineEdit.Prompt("yao>";
        prompt_prefix = () -> normal_prefix,
        prompt_suffix = Base.text_colors[:normal],
        on_enter = s->true)

    panel.hist = REPL.REPLHistoryProvider(Dict{Symbol,Any}(:debug => panel))
    REPL.history_reset_state(panel.hist)

    search_prompt, skeymap = LineEdit.setup_search_keymap(panel.hist)
    search_prompt.complete = REPL.LatexCompletions()

    panel.on_done = (s,buf,ok)->begin
        line = String(take!(buf))
        if !ok || strip(line) == "q"
            LineEdit.transition(s, :abort)
            LineEdit.reset_state(s)
            return false
        end
        if length(panel.hist.history) == 0
            printstyled(stderr, "no previous command executed\n"; color=Base.error_color())
            return false
        end
        if isempty(strip(line))
            command = panel.hist.history[end]
        else
            command = strip(line)
        end
        do_print_status = true
        cmd1 = split(command,' ')[1]
        do_print_status = try
            yaorepl_handler(command, state)
        catch err
            # This will only show the stacktrae up to the current frame because
            # currently, the unwinding in JuliaInterpreter unlinks the frames to
            # where the error is thrown

            # Buffer error printing
            io = IOContext(IOBuffer(), Base.pipe_writer(terminal))
            Base.display_error(io, err, JuliaInterpreter.leaf(state.frame))
            print(Base.pipe_writer(terminal), String(take!(io.io)))
            # Comment below out if you are debugging the Debugger
            #Base.display_error(Base.pipe_writer(terminal), err, catch_backtrace())
            LineEdit.transition(s, :abort)
            LineEdit.reset_state(s)
           return false
        end
        LineEdit.reset_state(s)
        if state.frame === nothing
            LineEdit.transition(s, :abort)
            LineEdit.reset_state(s)
            return false
        end
        if do_print_status
            print_status(Base.pipe_writer(terminal), active_frame(state); force_lowered = state.lowered_status)
        end
        return true
    end

    state.standard_keymap = Dict{Any,Any}[skeymap, LineEdit.history_keymap, LineEdit.default_keymap, LineEdit.escape_defaults]

    if initial_continue
        try
            execute_command(state, Val(:c), "c")
        catch err
            # Buffer error printing
            io = IOContext(IOBuffer(), Base.pipe_writer(terminal))
            Base.display_error(io, err, JuliaInterpreter.leaf(state.frame))
            print(Base.pipe_writer(terminal), String(take!(io.io)))
            return
        end
        state.frame === nothing && return state.overall_result
    end
    print_status(Base.pipe_writer(terminal), active_frame(state); force_lowered=state.lowered_status)
    REPL.run_interface(terminal, LineEdit.ModalInterface([panel,search_prompt]))

    return state.overall_result
end
