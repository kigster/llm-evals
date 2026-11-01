# LLM Evals:

## A Flexible CLI Framework for running multi-dataset, multi-case evaluation suites.

[![Gem Version](https://badge.fury.io/rb/llm-evals.svg)](https://rubygems.org/gems/llm-evals) [![CircleCI](https://dl.circleci.com/status-badge/img/gh/kigster/llm-evals/tree/main.svg?style=shield)](https://dl.circleci.com/status-badge/redirect/gh/kigster/llm-evals/tree/main) [![Ruby](https://github.com/kigster/llm-evals/actions/workflows/main.yml/badge.svg)](https://github.com/kigster/llm-evals/actions/workflows/main.yml) ![Coverage](docs/badges/coverage-badge.svg)

A flexible CLI for running multi-case evaluation suites and comparing LLMs and prompt configurations.

> [!IMPORTANT]
> This gem is not affiliated with the excellent [RubyLLM](https://rubyllm.com/) gem, though it uses RubyLLM under the hood.

> [!NOTE]
> The `llm-evals` gem installs two commands: `evals` and `llm-evals`. Use `llm-evals` if another installed package already provides the `evals` command. The CLI and runner use [Dry.rb](https://dry-rb.org/), and the default model connection uses OpenRouter.
>
> The gem also supports OpenTelemetry and can send evaluation data to services such as [Braintrust](https://braintrust.ai) and [W&B Weave](https://wandb.ai/site/weave/). Some design ideas came from [Pydantic Evals](https://pydantic.dev/logfire/evals).
>
> I originally developed the gem for [Qualified.At](https://qualified.at), a Ruby on Rails SaaS product.

## Evals are unit tests for probabilistic software

An eval checks whether a model meets the behavior you expect on a set of representative cases. Repeating the same cases lets you measure how prompts, parameters, and models affect the results. Your scorer decides whether those results are good; the eval makes the comparison consistent.

### References

- [AI Evals: Everything You Need to Know](https://hamel.dev/blog/posts/evals-faq/) (Hamel Husain)
- [Measure Against Quality Baselines](https://www.braintrust.dev/product/evaluate) (Braintrust)
- [Demystifying Evals for AI Agents](https://www.anthropic.com/research/demystifying-evals-for-ai-agents) (Anthropic)
- [Eval-Driven System Design: From Prototype to Production](https://developers.openai.com/cookbook/examples/partners/eval_driven_system_design/receipt_inspection) (OpenAI)
- [Independent Eval Research](https://www.braintrust.dev/evals) (Braintrust)
- [How to Build an LLM Eval Pipeline in GitHub Actions](https://www.braintrust.dev/articles/llm-eval-pipeline-github-actions) (Braintrust)

### A real-world example: Qualified.At

> [!NOTE]
> If you already know what evals are, feel free to skip this section.

This gem grew out of work on [Qualified.At](https://qualified.at), a lead-qualification and job-cost-estimation service. It uses the [Inquirex](https://github.com/inquirex) Ruby gems to define branching forms independently of how they are displayed. The same form can run in a terminal with [inquirex-tty](https://github.com/inquirex/inquirex-tty), or appear as a web form through the [inquirex-webui](https://www.npmjs.com/package/inquirex-webui) and [inquirex-widget](https://www.npmjs.com/package/inquirex-widget) packages.

On Qualified.At, a business can build an intake form in a visual editor or with an AI assistant, publish it, and add it to its website with a few lines of JavaScript. A visitor can open the form and answer questions before speaking with anyone. The forms can also start with a free-text description. An LLM extracts structured answers from that description, which can shrink a 20- or 30-question form to just a few follow-up questions.

You can [explore the ten demos](https://qualified.at/demos). The businesses are fictional, but the forms are live. A completed submission is saved to our database.

For example, someone visiting an [injury law firm](https://qualified.at/demos/personal-injury) or a [tax preparation firm](https://qualified.at/demos/tax-preparation) might want basic answers before calling. Personally, I like being able to answer a few questions and get an estimate without talking to anyone yet.

A tax customer might write: *"I'm married with three children, filing jointly, have three side businesses (two LLCs and an S-Corp), a rental property, a house I live in, a yacht my business bought for me, and a McLaren for the commute."* We can smile at the last part, but the useful point is that one paragraph may answer more than ten questions. The form can ask only for what's still missing.

### Why evals matter here

When we built Qualified.At, it wasn't clear which provider or model would extract answers most accurately from unstructured text and map them to a JSON schema. Accuracy matters, but so do latency and cost. At 1,000 leads, a cost of $0.0002 per call adds up to $0.20; a cost of $0.50 per call adds up to $500.

> [!IMPORTANT]
> Which model captures the most answers, assigns them correctly, avoids hallucinations, and doesn't miss details? We want accuracy with low cost and low latency. If a user waits 30 seconds to get to the next question, that's a problem.

That question is why I built this gem. The report below compares models on accuracy, completeness, latency, cost, and other metrics for this extraction task.

![LLM evaluation HTML report](docs/img/llm-evals-html-report.avif)

> [!NOTE]
> *The screenshot is a little out of date. I later reversed the model order so the best scores appear at the top. In this run, Anthropic's `claude-haiku-5.5` was the best fit for my priorities: speed, cost, and accuracy.*

I had used evals before and wanted to understand the ideas better and build something reusable for the Ruby community. Since this is a CLI tool, I use Dry.rb utilities such as `dry-cli`. I also maintain three extensions at [dry-cli.tools](https://dry-cli.tools).

## Datasets

Organize each use case as a dataset with multiple cases. The [cases-on-disk section](#cases-on-disk) shows the directory layout and how to add variants.

The gem runs every model in your lineup over every case in your folder, in parallel, and prints a leaderboard with scores, tokens and dollars.

You write two small classes: an **adapter** that asks the model, and a **scorer** that grades the answer.

The gem handles the rest:

- case discovery,
- the model lineup,
- providers,
- threads,
- progress bars,
- the leaderboard,
- and optional result reporting to Braintrust or Logfire.

### Why

Every LLM project grows its own eval script, and every one of them rebuilds the same runner, model list, thread pool and results table. This gem is that script, written once.

- **Scores reflect production.** Your adapter calls your real prompt builder and your real parser. The gem never touches what the model sees.
- **Compare settings, not just models.** `effort: [low, high]` and `temperature: [0.0, 0.7]` expand into one contender per combination.
- **Know the cheap winner.** "Best value" is the cheapest experiment within two points of the top score.
- **Failures are counted honestly.** A wrong answer scores 0. A network error is an error, not a 0. A model your suite cannot ask is left out by name, not scored.
- **No lock-in.** A local JSON log is always written. Braintrust, Logfire or your own tracker sits beside it.

## What you get

The bundled toy suite, run against two fake models (no network):

```text
$ evals compare --local
┌─────────┬─────────────┬─────────┬────────────────┬─────────────┬───────────┬────────┬─────────┐
│ dataset │ model       │ effort  │ field_accuracy │ exact_match │ restraint │ errors │    cost │
├─────────┼─────────────┼─────────┼────────────────┼─────────────┼───────────┼────────┼─────────┤
│ animals │ fake/echo   │ default │         100.0% │      100.0% │    100.0% │      0 │ $0.0040 │
│ animals │ fake/echo   │ low     │         100.0% │      100.0% │    100.0% │      0 │ $0.0040 │
│ animals │ fake/parrot │ default │         100.0% │      100.0% │    100.0% │      0 │ $0.0040 │
│ colors  │ fake/echo   │ default │         100.0% │      100.0% │    100.0% │      0 │ $0.0040 │
│ colors  │ fake/echo   │ low     │         100.0% │      100.0% │    100.0% │      0 │ $0.0040 │
│ colors  │ fake/parrot │ default │         100.0% │      100.0% │    100.0% │      0 │ $0.0040 │
└─────────┴─────────────┴─────────┴────────────────┴─────────────┴───────────┴────────┴─────────┘
```

This table is abridged. The full table also includes temperature, runtime, and input and output token counts. The report adds a glossary, a best-value summary for each dataset, and a leaderboard for each case variant. The model name appears last in each row and uses the same color as its progress bar. Use `--scores` to print every experiment ranked by score, with a link to its tracker. The report includes one column for each metric declared by your scorer.

## Run the examples

The repository ships two example suites. Both use fake models, so they need no API keys and no network. They live under `spec/fixtures/` and are **not** part of the installed gem, so start from a clone:

```bash
git clone https://github.com/kigster/llm-evals.git
cd llm-evals
bundle install
```

### The quick way: `just`

Run these commands from the repository root with [`just`](https://github.com/casey/just) installed (`brew install just`):

```bash
# Example 1: cases, verify, then compare --local
just toy

# Example 2: the same, for the config-only suite
just config-only

# Both
just examples

# Any other command, run inside the suite's folder
just toy compare -n
just toy run -m fake/echo -d animals --local
just config-only cases
```

The recipes change into each suite's folder and set `RUBYLIB` for the config-only suite. The following commands show how to run them by hand.

### Where to run from

`llm-evals` finds a suite by searching **upward from the current directory** for `evals/eval_helper.rb` or `evals/.llm-evals.config.yml`. The repository root has neither, so running there fails:

```text
$ bundle exec exe/evals cases
error: no suite is configured: register an adapter and a scorer in evals/eval_helper.rb, ...
```

Run the command from a suite's folder (the parent of its `evals/` directory), or pass the helper path with `--helper`.

### The toy suite (`eval_helper.rb` style)

If you use `just` then the easiest way to run the "toy" suite is with `just toy`.

But it helps to understand what's happening under the hood.

```bash
cd spec/fixtures/toy_suite

# List the 8 cases (2 datasets × 2 variants × 2 cases); calls nothing.
bundle exec evals cases

# Offline checks of inputs, expected.json, the adapter and the scorer.
bundle exec evals verify

# Show the experiment matrix the lineup expands into; calls nothing.
bundle exec evals compare -n

# One model, one dataset, with the per-case breakdown.
bundle exec evals run -m fake/echo -d animals --local

# Every model in the lineup, leaderboard only.
bundle exec evals compare --local
```

You can also run the command from the repository root and pass the helper path with `--helper`:

```bash
bundle exec exe/llm-evals compare --local --helper spec/fixtures/toy_suite/evals/eval_helper.rb
```

Files to look at:

| File (under `spec/fixtures/toy_suite/`) | What it shows                                              |
| --------------------------------------- | ---------------------------------------------------------- |
| `evals/eval_helper.rb`                  | `LLM::Evals.configure`: suite, cases glob, adapter, scorer |
| `lib/toy_suite/evals.rb`                | the adapter and scorer classes                             |
| `evals/.llm-evals.config.yml`           | the lineup, including a TypeSafe entry the suite refuses   |
| `evals/datasets/`                       | the case layout on disk                                    |

The warning `typesafe/jev-latest refused: needs typesafe; this suite produces prompt` is intentional: it shows a contender being left out rather than scored 0.

### The config-only suite (no `eval_helper.rb`)

This suite names its adapter and scorer in `.llm-evals.config.yml` instead of registering them in Ruby. Its `require: toy_suite/evals` must be loadable, which in a real project means a gem in your bundle. Here the code lives in the toy suite's `lib/`, so add it to the load path with `RUBYLIB`:

```bash
cd spec/fixtures/config_only_suite
RUBYLIB=../toy_suite/lib bundle exec evals cases
RUBYLIB=../toy_suite/lib bundle exec evals compare --local
```

Without `RUBYLIB` the run stops with `require: toy_suite/evals could not be loaded ... is its gem in the bundle?`.

### Against real models

Use the toy suite as a template:

1. Copy its `evals/` folder into your project.
1. Replace the adapter and scorer with your own (see [Writing a suite](#writing-a-suite)).
1. List real models under `openrouter:` in `.llm-evals.config.yml` and drop the `fake:` section.
1. Add `gem "ruby_llm"` to your Gemfile and set `OPENROUTER_API_KEY`, in your shell or the suite's `.env` (see [Environment](#environment)).

## Install

Install the CLI directly:

```bash
gem install llm-evals
```

Or add the gem to your Gemfile:

```ruby
gem "llm-evals"

# for OpenRouter, the default provider
gem "ruby_llm"

# only for the Braintrust tracker
gem "braintrust"

# only for the Logfire tracker
gem "opentelemetry-sdk"
gem "opentelemetry-exporter-otlp"
```

The gem requires Ruby 3.4 or later. `ruby_llm`, `braintrust`, and the OpenTelemetry gems are optional. They load only when a command needs them; if one is missing, the error names it.

## Writing a suite

The boundary runs one way:

- The **adapter** runs one case against a model and returns a `Reply`. It owns everything the model sees and everything done to its answer. It never scores.
- The **scorer** turns a case and a reply into a `Score`. It is pure and deterministic. It never calls anything.

Nothing in `lib/` knows what is being evaluated.

The executable looks for `evals/eval_helper.rb` upward from the current directory (or `--helper PATH`, or `LLM_EVALS_HELPER`), loads it, and dispatches. The helper calls `LLM::Evals.configure`:

```ruby
# evals/eval_helper.rb
require "bundler/setup"
require "llm/evals"
require "my_gem"

class MyAdapter < LLM::Evals::Adapter
  # Once per dataset, outside the threads.
  def prepare(dataset) = @schema = MyGem.schema_for(dataset)

  def call(kase, model:)
    completion = model.complete(
      system: MyGem.system_prompt(@schema), user: kase.input, json: true)
    
    # The production parser, so scores reflect production.
    output = MyGem.parse(completion.text)
    LLM::Evals::Reply.new(output: output, raw: completion.text, usage: completion.usage)
  rescue MyGem::NotJSON => e
    # The model's failure: scored 0.
    LLM::Evals::Reply.new(error: e.message, raw: completion&.text)
  end

  # What the scorer needs beyond the case.
  def context(kase) = { schema: @schema }

  # Offline, for `llm-evals verify`.
  def verify(dataset) = MyGem.schema_problems(dataset)
end

class MyScorer < LLM::Evals::Scorer
  def metrics
    [
      LLM::Evals::Metric.new(
        name: "field_accuracy",
        description: "Mean per-field score.",
        primary: true
      ),
      LLM::Evals::Metric.new(
        name: "exact_match",
        description: "1 when every field is right."
      ),
      LLM::Evals::Metric.new(
        name: "restraint",
        description: "Of the fields the text never answers, the share left null."
      )
    ]
  end

  def call(kase, reply, context:)
    scores = MyGem.field_scores(context[:schema], kase.expected, reply.output)
    mean = scores.values.sum / scores.size
    misses = scores.reject { |_, v| v == 1.0 }.keys

    LLM::Evals::Score.new(
      value: mean,
      metrics: {
        "field_accuracy" => mean,
        "exact_match" => scores.values.all?(1.0) ? 1.0 : 0.0,
        # nil: this case does not apply; it is skipped, not zeroed.
        "restraint" => nil
      },
      diagnostics: misses.to_h do |f| 
        [f, { want: kase.expected[f], got: reply.output[f] }] 
      end
    )
  end

  def verify(kase, context:)
    LLM::Evals::SchemaValidator.new(context[:schema]).problems(kase.expected)
  end

  def summary(kase) = "#{kase.expected.count { |_, v| !v.nil? }}/#{kase.expected.size} answered"
end

LLM::Evals.configure do |c|
  c.suite "extract", root: __dir__, env_files: ["../.env"]
  c.cases "datasets/*/cases/**/input.txt"
  c.adapter MyAdapter.new
  c.scorer MyScorer.new
  # After the env files load, before any model is called.
  c.before_run { MyGem.reset_configuration! }
end
```

A complete, runnable suite lives in [`spec/fixtures/toy_suite/evals/`](spec/fixtures/toy_suite/evals/): two datasets, two variants, the gem's own `Testing::EchoAdapter` and a fake provider. It runs without a network.

### A config-only suite

If your adapter and scorer live in your own gem, you can omit `eval_helper.rb` and name them in `.llm-evals.config.yml`:

```yaml
# evals/.llm-evals.config.yml
require: my_gem/evals              # a require path, or a list; loaded through the bundle's load path
adapter: MyGem::Evals::Adapter     # constant names, instantiated with no arguments
scorer: MyGem::Evals::Scorer
```

The executable searches upward from the working directory for `evals/.llm-evals.config.yml`, sets `evals/` as the suite root, loads the files listed under `require:`, and instantiates the two constants. `evals/` holds only the config file and `datasets/`:

```text
lib/my_gem/evals/adapter.rb        # the Ruby, in the gem
lib/my_gem/evals/scorer.rb
evals/.llm-evals.config.yml        # the lineup, plus require/adapter/scorer
evals/datasets/...
```

If `evals/eval_helper.rb` also exists, it loads first and may register either object in code; the config keys fill whatever it left unset. The required file may itself call `LLM::Evals.configure`, for instance to register a provider.

Errors identify the problem. If neither source provides an adapter or scorer, the error names the file and missing key. A failed `require:` or unknown constant names the key and value instead of showing only a `LoadError` or `NameError`. [`spec/fixtures/config_only_suite/`](spec/fixtures/config_only_suite/) is the toy suite in this form.

### Cases on disk

```text
evals/
  eval_helper.rb
  .llm-evals.config.yml           # the lineup and the request types
  datasets/<dataset>/cases/<variant>/[NNN/]input.txt
  datasets/<dataset>/cases/<variant>/[NNN/]expected.json
  datasets/<dataset>/cases/<variant>/[NNN/]metadata.json   # optional; merged into Case#metadata
```

- The folder after `datasets/` is the **dataset**.
- The folder holding `input.txt` is the **variant**, unless it is a number: then it is the case number and its parent is the variant.
- A case id is `variant/NNN`. `-c clear` selects a variant, `-c clear/003` one case.

Need another layout? Change the glob passed to `c.cases`.

### The lineup: `.llm-evals.config.yml`

The file at the suite root names the models to compare, their settings, and the kinds of request the suite sends:

```yaml
# evals/.llm-evals.config.yml
project: my-evals            # Env BRAINTRUST_PROJECT_ID takes precedence,
                             # but this is used as Braintrust project name

request_types: [prompt]      # required: what the suite's adapter sends

defaults:
  effort: default            # default sends none and leaves the model's own setting
  temperature: 0.1           # lower temp usually produce less variation (0 < t < 1)
  max_tokens: 8192           # covers the reasoning tokens a high effort spends
  parallelism: 4             # cases in flight per experiment; the default for -p

results:
  autosave: true             # save every completed run as JSON (default)
  destination: ./evals/results/
  temp_dir: ./tmp            # temporary JSON when autosave is false
  display: browser           # none, tui or browser

                             # A section named after a provider states the key it needs.
openrouter:                  # requires OPENROUTER_API_KEY; every entry takes a prompt
  rate_limit: { burst: 1000, per_minute: 500 }
  vendors:
    anthropic:
      rate_limit: { burst: 10, per_minute: 50 }
      models:
        - model: claude-opus-5                  # the vendor's limit only
        - model: claude-fable-5                 # both limits
          rate_limit: { burst: 5, per_minute: 20 }
        - model: claude-haiku-5.5
          effort: [default, low, high]          # a list expands into one contender per value
    openai:                                     # no limit of its own
      models:
        - model: gpt-6.1-sol
    typesafe:
      models:
        - model: jev-router                     # Jev on OpenRouter, a chat model

typesafe:                    # requires TYPESAFE_API_KEY; request type "typesafe": noul, choice, score
  models:
    - jev-latest             # a bare name is the same as `- model: jev-latest`
```

**Provider sections.** Each top-level key with `vendors:` or `models:` names a provider. An entry under `vendors:` becomes `<vendor>/<model>`, the OpenRouter id. An entry under `models:` becomes the provider's prefix and the name, such as `typesafe/jev-latest`. The contender carries its provider, so a direct `typesafe/jev-latest` and the OpenRouter chat model `typesafe/jev-router` never get confused. An unknown provider or key is a configuration error naming the file. The old top-level `vendors:` and `direct:` are errors too.

**Settings.** `effort` and `temperature` take one value or a list, and lists multiply: `effort: [low, high]` with `temperature: [0.0, 0.7]` runs four experiments for that model. Anything left out falls back to `defaults`. Flags (`-e`, `-t`, `--max-tokens`, `-p`) beat both.

**`rate_limit`.** It goes on a provider, a vendor or a model, and needs both numbers: the first `burst` calls of the run go at once, then `per_minute`, evenly spaced. A burst is spent once per run and does not refill. A model listed twice shares one limit, so setting it on both entries is an error. A call waits on every limit that matches it. Limits hold for one process across all `-j` and `-p`, and models given with `-m` obey them too. Time spent waiting is left out of `time`, `latency` and `p95`; `time` subtracts the wait averaged across the experiment's workers.

**Retries.** RubyLLM's retries are off. Rate limits, overloads, server errors and dropped connections are retried up to 5 attempts in all, and a retry shuts that vendor for every thread, for as long as `Retry-After` says or for 1, 2, 4 then 8 seconds when it says nothing. A provider asking for more than 5 minutes is not retried; the case counts as an error.

#### Weighted Score

> [!IMPORTANT]
> This is one of those features you never think you'd need, until you realize your results are sortable by a single column and it does not incorporate all of the others! What to do!? The answer is right here. Create a new score, weighted because it gives more or less weight to various resulting scores, and supports both results that are better when they are smaller (latency) and the ones that are better when they are larger (match %, accuracy %), etc.s

Say what matters most, and the leaderboard adds a `wscore` column, ranks by it, and names the best per dataset and overall:

```yaml
weighted_score:
  weights:                   # relative; a negative weight means lower is better
    score: 0.4               # the overall score, or any metric your scorer declares
    hallucinated_rate: -0.2  # a metric of your own
    cost: -0.2
    time: -0.1
    errors: -0.1             # one error takes 20 points off the total
```

`wscore = Σ(|weight| × goodness) / Σ|weight|`, from 0% to 100%, higher is better. Metrics count as they are, or as `1 - value` under a negative weight. When `errors` is weighted, errors come off the total: 20 points for one, 25 for two, 30 for three, and so on, down to 0%. A failed case has no metric scores, so the other weighted metrics do not reflect that failure. A contender with no errors earns the full positive contribution from the `errors` weight. `cost` and `time` go on a log scale between the lowest and highest in the table, so each doubling costs the same, however expensive the priciest model is. That makes a weighted score comparable only within one table.

`evals weights` prints each column's direction and real share of the score: `↓` in bold blue where low is good, `↑` in bold yellow where high is good. A scorer metric the weights leave out is listed in red with no values. Weights need not add up to 1.

You can weight `score`, `errors`, `time`, `cost`, `latency`, `p95` and your scorer's metrics. `latency` and `p95` are the average and 95th percentile seconds of the calls that worked (across datasets, a contender's `p95` is the average of each dataset's, an approximation good enough to rank by), while `time` is how long the experiment took, waiting included. Anything else, tokens included, is refused before a model is called. A contender missing a weighted value shows `-`, and one with errors cannot be named best. Without `weighted_score`, nothing changes.

#### Aborting a failing run

```yaml
errors:
  abort_after:
    total: 1000   # required
    percent: 60   # optional: also needs 60% of finished calls to have failed
```

Both limits must be met. A case counts as an error when the call raises or the model's reply is an error, such as one that is not JSON. Calls in flight finish, nothing new starts, the report is written from what finished, and the command exits non-zero. Without `errors`, a run never aborts.

#### Request types

`request_types` is required. It identifies the kind of request the suite's adapter sends. The types belong to the providers and show in `llm-evals --help`; a suite only names them:

| Type       | Provider                                    | Meaning                                              |
| ---------- | ------------------------------------------- | ---------------------------------------------------- |
| `prompt`   | OpenRouter (everything under `openrouter:`) | a chat completion: system and user text in, text out |
| `typesafe` | `typesafe:`                                 | typed questions: noul, choice, score                 |

A contender runs only when its provider's type is in the suite's list. Otherwise it is **refused**:

- named in the run's warnings: `typesafe/jev-latest refused: needs typesafe; this suite produces prompt`
- left out of the matrix and the leaderboard
- never scored 0: a model the suite cannot ask did not answer wrongly

`cases` prints refusals too, so a mismatch shows before anything runs. A missing, empty or unknown `request_types` is a configuration error naming the file.

## The command line

```bash
evals cases                              # list the cases, no calls
evals verify                             # offline checks: inputs, expected.json, adapter, scorer
evals run -m openai/gpt-4.1-mini         # one model, every dataset, per-case breakdown
evals run -m anthropic/claude-haiku-5.5 -e low -d vague -c vague/00
evals run --local -o                     # no remote tracker; the breakdowns go to log/
evals compare                            # run the configured model lineup
evals compare --format html -o report.html
evals compare --format json -o results.json # save every result for later rendering
evals render results.json -o report.html # render saved results; no model calls
evals compare -n                         # show that matrix, call nothing
evals completion zsh                     # shell completion (bash too)
```

| Command      | Does                                                 | Calls models |
| ------------ | ---------------------------------------------------- | ------------ |
| `cases`      | Lists cases and refused lineup entries               | no           |
| `verify`     | Checks inputs, `expected.json`, adapter and scorer   | no           |
| `run`        | Runs experiments; per-case breakdown and leaderboard | yes          |
| `compare`    | Runs experiments; leaderboard or saved report        | yes          |
| `render`     | Renders a saved JSON run as standalone HTML          | no           |
| `version`    | Prints the gem version (`-V`)                        | no           |
| `completion` | Prints a bash or zsh completion script               | no           |

- `cases` prints one row per case with its dataset, ID, difficulty, scorer summary, and word count.
- `verify` reports empty inputs and missing or unparsable `expected.json`, then runs `adapter.verify(dataset)` and `scorer.verify`.
- `run` and `compare` run one experiment per model and dataset, up to the machine's CPU count at a time. `-j N` / `--concurrency N` sets another limit, and `-j 0` starts them all together. `-p` is separate: the cases in flight inside each experiment.

Flags shared by `run` and `compare`: `-m/--models`, `-d/--dataset` (every dataset when omitted), `-c/--case`, `-e/--effort`, `-t/--temperature`, `--max-tokens`, `-p/--parallelism`, `-j/--concurrency`, `-C/--config FILE`, `--project NAME`, `--tracker NAME`, `--local`, `--no-open`, `-n/--dry-run`, `-o/--output [FILE]`, `--format tui|html|json`, `--totals overall|variant|both`, `--display none|tui|browser`, `--autosave/--no-autosave`, `--destination DIR` and `--temp-dir DIR`. `--totals` controls the TUI totals tables: the default `overall` compares contenders across all cases, `variant` compares each case folder (such as `complete` or `vague`) across datasets, and `both` prints both views. Completed runs are saved as timestamped JSON by default, independently of the selected display. Browser and TUI reports are rendered from that JSON; `--no-autosave` uses a temporary JSON snapshot under `temp_dir`. Use `llm-evals render results.json` to regenerate the HTML report without making model calls again. `-l` and `-L` are reserved for logging and not yet implemented.

**Reading the output.** `results.display` selects no report, a terminal leaderboard, or a browser report. The TUI has one column for each metric declared by the scorer and ranks by the primary metric. It also shows a glossary built from each metric's `description`. Browser reports show global and dataset standings, sortable tables, case inputs, expected answers, scores, and diagnostics. Provider names and model IDs use separate colors. Headline standings show effort and temperature alongside each model. Every JSON snapshot records both parsed CLI options and effective run settings, including expanded model settings and selected cases. `render` turns a saved snapshot into HTML later. Progress bars and warnings go to STDERR. Output from libraries is saved to `log/<command>.warnings.<stamp>.log` so it doesn't garble the terminal display.

## Trackers

The gem owns the run loop. A **tracker** sends results to an external service. The local JSON log is always written, and at most **one remote tracker** runs alongside it.

| Tracker      | Gems                                               | Key                  |
| ------------ | -------------------------------------------------- | -------------------- |
| local        | none                                               | none                 |
| `braintrust` | `braintrust`                                       | `BRAINTRUST_API_KEY` |
| `logfire`    | `opentelemetry-sdk`, `opentelemetry-exporter-otlp` | `LOGFIRE_TOKEN`      |

Choose one with `--tracker NAME`, or let its key select it (see selection order below). Braintrust also accepts `BRAINTRUST_PROJECT_ID` or `--project`.

Each tracker sends different data:

- **local** writes `log/llm-evals/<experiment>.<stamp>.json`: settings, means, errors, usage, and one row per case (score, metrics, outcomes, diagnostics, error, usage).
- **braintrust** creates one experiment per run in the project, with one eval row per case: input, expected, output (or `_error`), the scorer's metrics as scores, and diagnostics, outcomes and usage as metadata. The experiment page opens when the run finishes, unless `--no-open`.
- **logfire** sends OTLP traces to `https://logfire-us.pydantic.dev/v1/traces` (`LOGFIRE_BASE_URL` for another region): one span per experiment (suite, project, model, provider, settings, case count, means) with one child span per case (id, dataset, variant, score, each metric, outcome counts, duration, tokens and cost, diagnostics as JSON cut at 4 KB, exceptions recorded). Raw replies are not sent unless the config has `logfire: { include_replies: true }`. There is no page to open.

**Selection order:** `--tracker NAME`, then `tracker:` in `.llm-evals.config.yml`, then the environment, where exactly one tracker's key being set selects it.

- Two keys set and nothing chosen is an error asking for `--tracker` or `tracker:`.
- `--local` (or `--tracker none`) means no remote tracker.
- A chosen tracker whose gem or key is missing fails before any model is called, naming both.
- `-v` prints which tracker was chosen and why.

Logfire has no Ruby gem of its own. It is an OTLP backend for the standard OpenTelemetry Ruby SDK. The tracker builds its own tracer provider and exporter without changing the global provider. When `OTEL_EXPORTER_OTLP_ENDPOINT` or `OTEL_EXPORTER_OTLP_HEADERS` is already set, those win over `LOGFIRE_TOKEN`, and `-v` says so. The integration sends traces only. Logfire's metrics and logs SDKs are pre-1.0.

### Writing a tracker

A tracker is a class with three callbacks. Register it with `c.tracker` in the helper (or in a plugin gem loaded through `require:`), then choose it by name:

```ruby
class Weave < LLM::Evals::Tracker
  # Selects it when set and nothing else is chosen.
  def self.env_key = "WANDB_API_KEY"

  # Lazily required; named in the error when missing.
  def self.gems = ["wandb"]

  # Once, before the first case.
  def start(experiment)
    @run = Wandb.init(
      project: context[:project],
      name: experiment.name,
      config: { model: experiment.model.id, **experiment.model.settings }
    )
  end

  # Once per finished case, in order, under a lock.
  def record(result)
    @run.log(
      "case" => result.case.key,
      "score" => result.score&.value,
      **(result.score&.metrics || {}),
      "error" => result.error,
      "cost_usd" => result.reply&.usage&.cost_usd
    )
  end

  # Once, with the summary.
  def finish(experiment, summary)
    @run.summary.update(summary.means)
    @run.finish
    # Or { url: nil } when there is no page to open.
    { url: @run.url }
  end
end

LLM::Evals.configure { |c| c.tracker Weave }
```

`context` holds `suite:`, `project:`, `project_id:` and `options:` (the tracker's own section of the config file, e.g. `weave: { entity: "team" }`). Return `false` from `enabled?` to turn every callback into a no-op. To target another OTLP backend, subclass `Trackers::Logfire` with different credentials.

## Environment

| Variable                      | Used for                                                  |
| ----------------------------- | --------------------------------------------------------- |
| `OPENROUTER_API_KEY`          | required for any `openrouter:` model                      |
| `TYPESAFE_API_KEY`            | required for a `typesafe:` model                          |
| `BRAINTRUST_API_KEY`          | the Braintrust tracker; selects it when nothing else does |
| `BRAINTRUST_PROJECT_ID`       | Braintrust project UUID; beats the lineup's `project`     |
| `LOGFIRE_TOKEN`               | the Logfire tracker (a write token); selects it likewise  |
| `LOGFIRE_BASE_URL`            | Logfire region; default `https://logfire-us.pydantic.dev` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | when set, logfire uses it instead of `LOGFIRE_TOKEN`      |
| `OTEL_EXPORTER_OTLP_HEADERS`  | likewise                                                  |
| `LLM_EVALS_HELPER`            | a helper to load instead of searching upward              |

The suite loads files listed in `env_files`, without overriding variables already exported in the environment. A missing key fails the run before any model is called, naming the variable.

## Writing a provider

A provider wraps an API. It declares the request types it supports, required keys, available models, and a `complete` method.

- A provider declares the ids it serves with `prefix`, and its section in the lineup carries its `name`.
- A `direct?` provider is reached only through its own section.
- Register it with `c.provider`. Providers are checked in reverse registration order for an ID outside a direct provider's section. OpenRouter claims every ID, so it is always checked last.

```ruby
class Ollama < LLM::Evals::Providers::Base
  HOST = "http://localhost:11434"

  def name = "ollama"

  # Admitted by a suite declaring prompt.
  def request_type = :prompt

  # Shown in --help; a suite never spells it.
  def request_type_description = "a chat completion"

  # Serves "ollama/<model>".
  def prefix = "ollama/"

  # Local, no key.
  def env_keys = []

  # Takes no reasoning effort.
  def efforts = []

  def catalog
    tags = JSON.parse(Net::HTTP.get(URI("#{HOST}/api/tags")))
    tags.fetch("models").map { "ollama/#{it["name"]}" }
  end

  def complete(model, system:, user:, json: true)
    body = {
      model: model.name,
      system: system,
      prompt: user,
      format: (json ? "json" : nil),
      stream: false
    }.compact
    response = JSON.parse(
      Net::HTTP.post(URI("#{HOST}/api/generate"), JSON.generate(body)).body
    )

    LLM::Evals::Completion.new(
      text: response.fetch("response"),
      usage: {
        input_tokens: response["prompt_eval_count"],
        output_tokens: response["eval_count"],
        cost_usd: 0.0
      },
      raw: response
    )
  end
end

LLM::Evals.configure { |c| c.provider Ollama.new }
```

`model.effort`, `model.temperature` and `model.max_tokens` carry the contender's settings; nil means "send nothing". A transport failure should raise: the run counts it as an error, not as a wrong answer.

`Providers::TypeSafe` is a direct provider (`typesafe:`, request type `typesafe`). It ships with TypeSafe's model list, key and pricing, which is enough for `verify` and the cost column. Its `complete` is not implemented yet and raises "no typesafe consumer yet": the typed request shape will be defined by the first suite that declares `request_types: [typesafe]`.

## Public API

```ruby
module LLM::Evals
  Case       = Data.define(
    :id, :dataset, :variant, :input, :expected, :path, :metadata)
  Usage      = Data.define(
    :input_tokens, :output_tokens, :cost_usd)
  Completion = Data.define(
    :text, :usage, :raw)
  # error: the model failed, scored 0. A raise: transport failure.
  Reply      = Data.define(
    :output, :raw, :usage, :error, :metadata)
  # aggregate: :mean, skipping nil.
  Metric     = Data.define(
    :name, :description, :aggregate, :primary)
  # value: 0..1; metrics: { name => Float | nil }.
  Score      = Data.define(
    :value, :metrics, :outcomes, :diagnostics)
  RunResult  = Data.define(
    :experiment, :case, :reply, :score, :duration, :error)
  # provider: nil, or a direct provider's name.
  Contender  = Data.define(
    :model, :effort, :temperature, :max_tokens, :provider)

  class Model
    attr_reader :id, :provider, :settings
    def complete(system: nil, user:, json: true) = Completion
  end

  class Adapter
    def prepare(dataset)
    def call(kase, model:)
    def context(kase)
    def verify(dataset)
    def metadata
  end

  class Scorer
    def metrics
    def call(kase, reply, context:)
    def verify(kase, context:)
    def summary(kase)
  end

  # Schema: { name => { type:, enum:, nullable: } }.
  # Types: boolean, integer, number, string, enum, multi_enum.
  class SchemaValidator

  # One model over one dataset, on the gem's own thread pool; trackers watch.
  class Experiment

  # start(experiment), record(run_result), finish(experiment, summary) -> { url: }
  class Tracker

  # Local (always), Braintrust, Logfire (OTLP), Registry (choose).
  module Trackers

  # Base (request_type, direct?), Registry (for, direct, admit), 
  # OpenRouter, TypeSafe, Catalog.
  module Providers

  # EchoAdapter, FakeProvider, FakeModel.
  module Testing

  # Config#request_types is required; Config::REQUEST_TYPES = %w[prompt typesafe].
  class Discovery, Config, Configuration, Runtime, Verify, Warnings, Launcher
end
```

## Development

```bash
# Install the bundle
just install

# RuboCop, RSpec (coverage >= 95%), both example suites; no network
just ci

# Both example suites through the executable: cases, verify, compare --local
just examples

# Build the .gem into pkg/; publishing to RubyGems requires an OTP
just build
just publish

# Install the pre-commit hooks
lefthook install
```

Specs create real directories under `Dir.mktmpdir` and never access the network. They stub `RubyLLM`, the Braintrust API classes, and `Net::HTTP`. Tracker behavior is checked with OpenTelemetry's in-memory span exporter.

## License

MIT. See [LICENSE.txt](LICENSE.txt).

## Author

Written by Konstantin Gredeskoul, © 2026 for the [Qualified.At](https://qualified.at) project.

## Contributions

Are welcome! Submit a PR, an issue, we love to collaborate!
