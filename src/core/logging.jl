"MetaFormatter for ConsoleLogger Inspired by PowerModelsDistribution v0.11"
function _pmdse_metafmt(level::Logging.LogLevel, _module, file, line)
    @nospecialize
    color = Logging.default_logcolor(level)
    prefix = "$(_module) | " * (level == Logging.Warn ? "Warning" : string(level)) * " ] :"
    suffix = ""
    Logging.Info <= level < Logging.Warn && return color, prefix, suffix
    _module !== nothing && (suffix *= "$(_module)")
    if file !== nothing
        _module !== nothing && (suffix *= " ")
        suffix *= Base.contractuser(file)
        if line !== nothing
            suffix *= ":$(isa(line, UnitRange) ? "$(first(line))-$(last(line))" : line)"
        end
    end
    !isempty(suffix) && (suffix = "@ " * suffix)

    return color, prefix, suffix
end


"Sets loglevel for PMDSE to :Wanr, silencing Info. To be set to :Error after old 1functions in 0.2.4 are deprecated"
function silence!()
    set_logging_level!(:Warn)
end


"Resets the log level to Info"
function reset_logging_level!()
    Logging.global_logger(_LOGGER)

    return
end


"Restores the global logger to its default state (before PMDSE was loaded)"
function restore_global_logger!()
    Logging.global_logger(_DEFAULT_LOGGER)

    return
end


"Sets the logging level for PMDSE: :Info, :Warn, :Error"
function set_logging_level!(level::Symbol)
    Logging.global_logger(_make_filtered_logger(getfield(Logging, level)))

    return
end


"Helper function to create the filtered logger for PMDSE"
function _make_filtered_logger(level)
    LoggingExtras.EarlyFilteredLogger(_LOGGER) do log
        if log._module == PowerModelsDistributionStateEstimation && log.level < level
            return false
        else
            return true
        end
    end
end