defmodule Benchee.Configuration do
  @moduledoc """
  Functions to handle the configuration of Benchee, exposes `init` function.
  """

  alias Benchee.Conversion.Duration
  alias Benchee.Utility.DeepConvert
  alias Benchee.Suite

  defstruct [
    parallel:          1,
    time:              5,
    warmup:            2,
    formatters:        [&Benchee.Formatters.Console.output/1],
    print: %{
      benchmarking:    true,
      configuration:   true,
      fast_warning:    true
    },
    inputs:            nil,
    # formatters should end up here but known once are still picked up at
    # the top level for now
    formatter_options: %{
      console: %{
        comparison:    true,
        unit_scaling:  :best
      }
    },
    # If you/your plugin/whatever needs it your data can go here
    assigns:           %{}
  ]

  @type t :: %__MODULE__{
    parallel:          integer,
    time:              number,
    warmup:            number,
    formatters:        [((Suite.t) -> Suite.t)],
    print:             map,
    inputs:            %{Suite.key => any} | nil,
    formatter_options: map,
    assigns:           map
  }

  @type user_configuration :: map | keyword
  @time_keys [:time, :warmup]

  @doc """
  Returns the initial benchmark configuration for Benchee, composed of defaults
  and an optional custom configuration.

  Configuration times are given in seconds, but are converted to microseconds
  internally.

  Possible options:

    * `time`       - total run time in seconds of a single benchmark (determines
    how often it is executed). Defaults to 5.
    * `warmup`     - the time in seconds for which the benchmarking function
    should be run without gathering results. Defaults to 2.
    * `inputs` - a map from descriptive input names to some different input,
    your benchmarking jobs will then be run with each of these inputs. For this
    to work your benchmarking function gets the current input passed in as an
    argument into the function. Defaults to `nil`, aka no input specified and
    functions are called without an argument.
    * `parallel`   - each the function of each job will be executed in
    `parallel` number processes. If `parallel` is `4` then 4 processes will be
    spawned that all execute the _same_ function for the given time. When these
    finish/the time is up 4 new processes will be spawned for the next
    job/function. This gives you more data in the same time, but also puts a
    load on the system interfering with benchmark results. For more on the pros
    and cons of parallel benchmarking [check the
    wiki](https://github.com/PragTob/benchee/wiki/Parallel-Benchmarking).
    Defaults to 1 (no parallel execution).
    * `formatters` - list of formatter functions you'd like to run to output the
    benchmarking results of the suite when using `Benchee.run/2`. Functions need
    to accept one argument (which is the benchmarking suite with all data) and
    then use that to produce output. Used for plugins. Defaults to the builtin
    console formatter calling `Benchee.Formatters.Console.output/1`.
    * `print`      - a map from atoms to `true` or `false` to configure if the
    output identified by the atom will be printed. All options are enabled by
    default (true). Options are:
      * `:benchmarking`  - print when Benchee starts benchmarking a new job
      (Benchmarking name ..)
      * `:configuration` - a summary of configured benchmarking options
      including estimated total run time is printed before benchmarking starts
      * `:fast_warning`  - warnings are displayed if functions are executed
      too fast leading to inaccurate measures
    * `console` - options for the built-in console formatter. Like the
    `print` options the boolean options are also enabled by default:
      * `:comparison`   - if the comparison of the different benchmarking jobs
      (x times slower than) is shown (true/false)
      * `:unit_scaling` - the strategy for choosing a unit for durations and
      counts. When scaling a value, Benchee finds the "best fit" unit (the
      largest unit for which the result is at least 1). For example, 1_200_000
      scales to `1.2 M`, while `800_000` scales to `800 K`. The `unit_scaling`
      strategy determines how Benchee chooses the best fit unit for an entire
      list of values, when the individual values in the list may have different
      best fit units. There are four strategies, defaulting to `:best`:
          * `:best`     - the most frequent best fit unit will be used, a tie
          will result in the larger unit being selected.
          * `:largest`  - the largest best fit unit will be used (i.e. thousand
          and seconds if values are large enough).
          * `:smallest` - the smallest best fit unit will be used (i.e.
          millisecond and one)
          * `:none`     - no unit scaling will occur. Durations will be displayed
          in microseconds, and counts will be displayed in ones (this is
          equivalent to the behaviour Benchee had pre 0.5.0)

  ## Examples

      iex> Benchee.init
      %Benchee.Suite{
        configuration:
          %Benchee.Configuration{
            parallel: 1,
            time: 5_000_000,
            warmup: 2_000_000,
            inputs: nil,
            formatters: [&Benchee.Formatters.Console.output/1],
            print: %{
              benchmarking: true,
              fast_warning: true,
              configuration: true
            },
            formatter_options: %{
              console: %{ comparison: true, unit_scaling: :best }
            },
            assigns: %{}
          },
        jobs: %{},
        run_times: nil,
        statistics: nil,
        system: nil
      }

      iex> Benchee.init time: 1, warmup: 0.2
      %Benchee.Suite{
        configuration:
          %Benchee.Configuration{
            parallel: 1,
            time: 1_000_000,
            warmup: 200_000.0,
            inputs: nil,
            formatters: [&Benchee.Formatters.Console.output/1],
            print: %{
              benchmarking: true,
              fast_warning: true,
              configuration: true
            },
            formatter_options: %{
              console: %{ comparison: true, unit_scaling: :best }
            },
            assigns: %{}
          },
        jobs: %{},
        run_times: nil,
        statistics: nil,
        system: nil
      }

      iex> Benchee.init %{time: 1, warmup: 0.2}
      %Benchee.Suite{
        configuration:
          %Benchee.Configuration{
            parallel: 1,
            time: 1_000_000,
            warmup: 200_000.0,
            inputs: nil,
            formatters: [&Benchee.Formatters.Console.output/1],
            print: %{
              benchmarking: true,
              fast_warning: true,
              configuration: true
            },
            formatter_options: %{
              console: %{ comparison: true, unit_scaling: :best }
            },
            assigns: %{}
          },
        jobs: %{},
        run_times: nil,
        statistics: nil,
        system: nil
      }

      iex> Benchee.init(
      ...>   parallel: 2,
      ...>   time: 1,
      ...>   warmup: 0.2,
      ...>   formatters: [&IO.puts/2],
      ...>   print: [fast_warning: false],
      ...>   console: [unit_scaling: :smallest],
      ...>   inputs: %{"Small" => 5, "Big" => 9999},
      ...>   formatter_options: [some: "option"])
      %Benchee.Suite{
        configuration:
          %Benchee.Configuration{
            parallel: 2,
            time: 1_000_000,
            warmup: 200_000.0,
            inputs: %{"Small" => 5, "Big" => 9999},
            formatters: [&IO.puts/2],
            print: %{
              benchmarking: true,
              fast_warning: false,
              configuration: true
            },
            formatter_options: %{
              console: %{ comparison: true, unit_scaling: :smallest },
              some: "option"
            },
            assigns: %{}
          },
        jobs: %{},
        run_times: nil,
        statistics: nil,
        system: nil
      }
  """
  @spec init(user_configuration) :: Suite.t
  def init(config \\ %{}) do
    :ok    = :timer.start

    config = config
             |> standardized_user_configuration
             |> merge_with_defaults
             |> convert_time_to_micro_s

    %Suite{configuration: config}
  end

  defp standardized_user_configuration(config) do
    config
    |> DeepConvert.to_map
    |> translate_formatter_keys
    |> force_string_input_keys
  end

  # backwards compatible translation of formatter keys to go into
  # formatter_options now
  @formatter_keys [:console, :csv, :json, :html]
  defp translate_formatter_keys(config) do
      {formatter_options, config} = Map.split(config, @formatter_keys)
    DeepMerge.deep_merge(%{formatter_options: formatter_options}, config)
  end

  defp force_string_input_keys(%{inputs: inputs} = config) do
    standardized_inputs = for {name, value} <- inputs, into: %{} do
                            {to_string(name), value}
                          end
    %{config | inputs: standardized_inputs}
  end
  defp force_string_input_keys(config), do: config

  defp merge_with_defaults(user_config) do
    DeepMerge.deep_merge(%Benchee.Configuration{}, user_config)
  end

  defp convert_time_to_micro_s(config) do
    Enum.reduce @time_keys, config, fn(key, new_config) ->
      {_, new_config} = Map.get_and_update! new_config, key, fn(seconds) ->
        {seconds, Duration.microseconds({seconds, :second})}
      end
      new_config
    end
  end
end

defimpl DeepMerge.Resolver, for: Benchee.Configuration do
  def resolve(_original, override = %{__struct__: Benchee.Configuration}, _) do
    override
  end
  def resolve(original, override, resolver) when is_map(override) do
    merged = Map.merge(original, override, resolver)
    struct! Benchee.Configuration, Map.to_list(merged)
  end
end