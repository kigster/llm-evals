# LLM Evals

## CLI command: `llm-evals` or just `evals`

[![Gem Version](https://badge.fury.io/rb/llm-evals.svg)](https://rubygems.org/gems/llm-evals) [![CircleCI](https://dl.circleci.com/status-badge/img/gh/kigster/llm-evals/tree/main.svg?style=shield)](https://dl.circleci.com/status-badge/redirect/gh/kigster/llm-evals/tree/main) ![coverage](docs/badges/coverage-badge.svg)

> [!CAUTION]
> This gem is not directly affiliated with the most excellent [ruby_llm](https://rubyllm.com/) ruby gem, but it uses it under the hood.

> [!NOTE]
> This is a CLI-based gem which installs the command `evals` as well as `llm-evals` if for some reason `evals` is already reserved on your system. The gem is based on DryRb series of gems for it's CLI and main processing module, and on OpenRouter for LLM model connectivity and evaluation.
>
> In addition, this gem supports OpenTelemetry, and can be wrapped in commercial providers of evals tracing and historical tracking such as [BrainTrust](https://braintrust.ai), [W&B Weave](https://wandb.ai/site/weave/) and others, and borrows many ideas from [Pydantic Evals](https://pydantic.dev/logfire/evals).
>
> The gem was developed for the Ruby/Rails SaaS site [Qualified.AT](https://qualified.at)

## **Evals are the AI-era unit tests.**

Evals ensure that given a set of conditions, or inputs (or prompts), your probabilistic answer from the LLM remains consistent (whether it's a good answer or a bad one is another question, but consistency is what's so hard to get right out of a probabilistic LLM).

If you are new to evals, I strongly suggest that you consider the following example, for which this gem was originally built — a mini SaaS product [Qualified.At](https://qualified.at) (lead qualification and job cost estimation) — that is built atop of a collection of three MIT-licensed Ruby Gems and two MIT-licensed NPM packages, under the Github Org ["inquirex"](https://github.com/inquirex).

#### References

- [AI Evals: Everything You Need to Know](https://hamel.dev/blog/posts/evals-faq/) (hamel.dev)
- [Measure against quality baselines](https://www.braintrust.dev/product/evaluate) (Braintrust)
- [Demystifying evals for AI agents](https://www.anthropic.com/research/demystifying-evals-for-ai-agents) (Anthropic)
- [Eval Driven System Design - From Prototype to Production](https://developers.openai.com/cookbook/examples/partners/eval_driven_system_design/receipt_inspection) (OpenAI)
- [Independent eval research. Open methodology, published datasets, and the tools to run your own studies.](https://www.braintrust.dev/evals) (Braintrust)
- [How to build an LLM eval pipeline in GitHub Actions](https://www.braintrust.dev/articles/llm-eval-pipeline-github-actions) (Braintrust)

### A Real World Example and a Birthplace of this Gem

> [!NOTE]
> ***If you are familiar with evals, feel free to skip this section.***

The [Inquirex](https://github.com/inquirex) gems provide a powerful DSL for building potentially complex and multi-branching (based on answers) forms with multiple branches of questions, that are decoupled from the rendering engine. Therefore the same exact DSL code defining a form flow, can be rendered in the Terminal using the [inquirex-tty](https://github.com/inquirex/inquirex-tty) gem, or shown in a copilot popup as an HTML form, using NPM modules [inquirex-webui](https://www.npmjs.com/package/inquirex-webui) and [inquirex-widget](https://www.npmjs.com/package/inquirex-widget).

The freemium site [Qualified.At](https://qualified.at) uses the above gems and the DSL they define as an intermediary format for arbitrarily complex intake forms which you can create using a visual editor, or using an AI assistant. You create a form with it's questions and branches, and when you are ready you "publish" it, and copy/paste a few lines of JavaScript on your site. Once there, a visitor comes alone and a pop-up will appear, based on how you configured it, either on click of something, or after a custom delay after the page is done loading. You can even style the copilot automatically to look like your site. So, you've set all these preferences in your account on ***qualified.at***, and the JS served to you includes digests and various security measures to ensure only your site can send leads, and that only that form appears to the visitors to your site and can only be used from the domain you configured.

> The best way to understand the entire concept is to [explore the all ten demos on the site](https://qualified.at/demos), which are all fictitious businesses, of course, but the forms that pop up from the bottom right bubble are live and very real, and if you go through to the end it will save you to our database.

So, leads come to your site, and they might see a copilot form they can interact with.

Say you are an [injury lawfirm](https://qualified.at/demos/personal-injury), or a [tax preparation firm](https://qualified.at/demos/tax-preparation), and I have a legal problem or a work-place injury. I might want to get some very basic answers before I get on the phone, and so I visit the site, and personally, I would be stoked that I don't have to speak to anyone (yet) and that I can just answer some the questions, and perhaps get a quote back.

**The "innovation" here comes from the ability of the form creator to start the form from a free-text field** that the visitor is encouraged to fill out with as much detail as possible, without sharing any PII information, besides their email in the end, **and have that text be sent to an LLM for structured analysis**, to see if perhaps some of the questions down below may have already been answered by the user. This is the case where a 20-30 question form might magically shrink to 4-5 questions + your introductory write-up.

> [!NOTE]
> For instance, for a Tax Prep service, you might write: ***"I am married with three children, filing jointly, have three side businesses (two LLCs and an S-Corp), a rental property, a house I live in, and yacht that my business purchased for me, with a MacLauren for the commute."*** We can laugh about the fact that this person clearly doesn't get the US Tax system, but what's relevant here is that they provided answers to over 10-15 questions that would have otherwise followed.

### So How do Evals Help Here?

When the service ***qualified.at*** was being built, **it was not at all obvious which vendor, and which model would do the best type of extraction** from an unstructured text to the structured, conforming to a JSON schema mapped to the answers below. Besides accuracy, there are also such parameters as latency (you don't want the user to wait 30 seconds), as well as the cost. For 1000 leaks a cost of 0.0002$ is insignificant. But a cost of $0.5 per call is very much significant.

> [!IMPORTANT]
> So, finally we arrive to the question of the day: **which model should I use? Which model captures the most answers, correctly assigns them, does not assign something random (hallucinate), does not miss any answer from the text? And so on.** We want accuracy coupled with low cost and low latency. If the user has to wait 30 seconds to get to the next question, that's a problem.

So this is how this gem was born. And not to spout many empty words, here is the HTML report produced by my eval suite and this gem for this specific questions answered: which model is the best when you include price, latency, accuracy, correctness, completeness, and five other factors!

![results](docs/img/llm-evals-html-report.avif)

This screenshot is somewhat outdated. I've since reversed the order of the models, so the highest scores (best results) show up at the top, not the other way around. But still, the conclusion is clear as day:

> [!IMPORTANT]
> The best model for extraction, by speed, cost, accuracy and everything important to me is anthropic's `claude-haiku-5.5`

______________________________________________________________________

I've had some experience with evals before, and I wanted to dig deeper into the ideas and concept surrounding them, and build something reusable for the open source community at large. And considering that there is already a Rails integrated version of this concept, in my CLI tooling I lean on DryRB utilities such as `dry-cli`, for which I released three extension gems at **[dry-cli.tools](https://dry-cli.tools).**

______________________________________________________________________

## Datasets

This gem relies on you to organize your use-cases in `evals/datasets/<dataset-name>` folders, and for each dataset you should create multiple "cases", so the full structure is `evals/datasets/<dataset-name>/<case>` a case that is different from the rest. You get a sense for this after a lot of trial and error, but say you accomplished the result.

The gem runs every model in your lineup over every case in your folder, in parallel, and prints a leaderboard with scores, tokens and dollars.

You write two small classes: an **adapter** that asks the model, and a **scorer** that grades the answer.

The gem does the rest:

- case discovery,
- the model lineup,
- providers,
- threads,
- progress bars,
- the leaderboard,
- and sending results to Braintrust or Logfire if you so desire.

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

Abridged: the real table also has `temp`, `time`, `tok_in` and `tok_out` columns. It's followed by the best value per dataset, in aligned columns with each model last, in the color of its progress bars, after a glossary of every column and a leaderboard for each case variant, over every dataset, so the conclusions come last. `--scores` also prints every experiment by score, with its tracker's link. There is one column per metric your scorer declares.

## Run the examples

The repository ships two example suites. Both use fake models, so they need no API keys and no network. They live under `spec/fixtures/` and are **not** part of the installed gem, so start from a clone:

```bash
git clone https://github.com/kigster/llm-evals.git
cd llm-evals
bundle install
```

### The short way: `just`

From the repository root, with [`just`](https://github.com/casey/just) installed (`brew install just`)

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

The recipes `cd` into the suite's folder for you and, for the config-only suite, set `RUBYLIB` too. The rest of this section is what they do by hand.

### Where to run from

`llm-evals` finds its suite by searching **upward from the current directory** for `evals/eval_helper.rb` or `evals/.llm-evals.config.yml`. The repository root has neither, so running there fails:

```text
$ bundle exec exe/evals cases
error: no suite is configured: register an adapter and a scorer in evals/eval_helper.rb, ...
```

Either `cd` into a suite's folder (the parent of its `evals/`), or point at the helper with `--helper`.

## Examples

The gem comes with two somewhat contrived examples, which live in `spec/fixtures` folder.

You can run both of them from the gem source's root folder by using `just`:

```bash
just examples
```

You should see the header for "Toy Suite," then for "Config Only Suite."

You can run individual examples with `just toy` and `just config-only`.

But let's dive a bit deeper.

### 1. The toy suite (`eval_helper.rb` style)

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

The same commands work from the repository root with `--helper`:

```bash
bundle exec exe/llm-evals compare --local --helper spec/fixtures/toy_suite/evals/eval_helper.rb
```

What to read in it:

| File (under `spec/fixtures/toy_suite/`) | What it shows                                              |
| --------------------------------------- | ---------------------------------------------------------- |
| `evals/eval_helper.rb`                  | `LLM::Evals.configure`: suite, cases glob, adapter, scorer |
| `lib/toy_suite/evals.rb`                | the adapter and scorer classes                             |
| `evals/.llm-evals.config.yml`           | the lineup, including a `direct:` entry the suite refuses  |
| `evals/datasets/`                       | the case layout on disk                                    |

The warning `typesafe/jev-latest refused: needs typesafe; this suite produces prompt` is intentional: it shows a contender being left out rather than scored 0.

### 2. The config-only suite (no `eval_helper.rb`)

The same suite, with the adapter and scorer named in `.llm-evals.config.yml` instead of Ruby. Its `require: toy_suite/evals` must be loadable, which in a real project means a gem in your bundle. Here the code lives in the toy suite's `lib/`, so add it to the load path with `RUBYLIB`:

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
1. List real models under `vendors:` in `.llm-evals.config.yml` and drop the `fake:` entries.
1. Add `gem "ruby_llm"` to your Gemfile and set `OPENROUTER_API_KEY`, in your shell or the suite's `.env` (see [Environment](#environment)).

## Install

```ruby
# Gemfile
gem "llm-evals"

# for OpenRouter, the default provider
gem "ruby_llm"

# only for the braintrust tracker
gem "braintrust"

# only for the logfire tracker
gem "opentelemetry-sdk"
gem "opentelemetry-exporter-otlp"
```

Requires Ruby 3.4 or later. `ruby_llm`, `braintrust` and the OpenTelemetry gems are optional: they load only when a command needs them, and a missing one is named in the error.

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

When the adapter and scorer live in your own gem, you need no `eval_helper.rb`. Three optional keys in `.llm-evals.config.yml` name them:

```yaml
# evals/.llm-evals.config.yml
require: my_gem/evals              # a require path, or a list; loaded through the bundle's load path
adapter: MyGem::Evals::Adapter     # constant names, instantiated with no arguments
scorer: MyGem::Evals::Scorer
```

The executable finds `evals/.llm-evals.config.yml` upward from the working directory, roots the suite at `evals/`, requires what `require:` names and instantiates the two constants. `evals/` holds only the config file and `datasets/`:

```text
lib/my_gem/evals/adapter.rb         # the Ruby, in the gem
lib/my_gem/evals/scorer.rb
evals/.llm-evals.config.yml        # the lineup, plus require/adapter/scorer
evals/datasets/...
```

If `evals/eval_helper.rb` also exists, it loads first and may register either object in code; the config keys fill whatever it left unset. The required file may itself call `LLM::Evals.configure`, for instance to register a provider.

Errors name what is wrong: no adapter or scorer from either source names the file and the keys; a failing `require:` or an unknown constant names the key and its value instead of a bare `LoadError` or `NameError`. [`spec/fixtures/config_only_suite/`](spec/fixtures/config_only_suite/) is the toy suite in this form.

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
project: my-evals            # Braintrust project name 
	                           # (BRAINTRUST_PROJECT_ID wins when set)
request_types: [prompt]      # required: what the suite's adapter sends

defaults:
  effort: default            # default sends none and leaves the model's own setting
  temperature: 0.1           # lower temperature produces less variation 0 < t < 1
  max_tokens: 8192           # covers the reasoning tokens a high effort spends
  parallelism: 4             # cases in flight per experiment; the default for -p

results:
  autosave: true             # save every completed run as JSON (default)
  destination: ./evals/results/
  temp_dir: ./tmp            # temporary JSON when autosave is false
  display: browser           # none, tui or browser

                             # This section requires OPENROUTER_API_KEY
vendors:                     # the OpenRouter list; every entry takes a prompt
  anthropic:
    - model: claude-fable-5
    - model: claude-opus-5
    - model: claude-sonnet-5.5
    - model: claude-haiku-5.5
      effort: [default, low, high]   # a list expands into one contender per value
  openai:
    - model: gpt-4.1-mini
    - model: gpt-4o-mini
    - model: gpt-6.1-sol
  google:
    - model: gemini-2.5-flash
    - model: gemini-4-argon
  meta-llama:
    - model: llama-3.3-70b-instruct
  typesafe:
    - model: jev-router      # Jev on OpenRouter, a chat model
  moonshotai:
    - model: kimi-k3

direct:                      # a vendor's own API, one request type each
  typesafe:                  # request type "typesafe": noul, choice, score
    - model: jev-latest      # and this requires TYPESAFE_API_KEY
```

**`vendors:`** Each entry becomes `<vendor>/<model>`, the OpenRouter id. `effort` and `temperature` take one value or a list, and lists multiply: `effort: [low, high]` with `temperature: [0.0, 0.7]` runs four experiments for that model. Anything left out falls back to `defaults`. Flags (`-e`, `-t`, `--max-tokens`, `-p`) beat both.

**`direct:`** Each key names a provider the gem knows (today only `typesafe`). Entries take the same `{model:, effort:, temperature:, max_tokens:}` format, expand the same way, and render as `typesafe/jev-latest`. The contender carries its provider, so a direct `typesafe/jev-latest` and the OpenRouter chat model `typesafe/jev-router` never get confused. An unknown key is a configuration error naming the file and the known providers.

#### Weighted score

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

`wscore = Σ(|weight| × goodness) / Σ|weight|`, from 0% to 100%, higher is better. Metrics count as they are, or as `1 - value` under a negative weight. When `errors` is weighted, errors come off the total: 20 points for one, 25 for two, 30 for three, and so on, down to 0%. A failed case has no scores, so no other column notices it. A clean contender gets the whole of the weight on `errors`. `cost` and `time` go on a log scale between the lowest and highest in the table, so each doubling costs the same, however expensive the priciest model is. That makes a weighted score comparable only within one table.

You can weight `score`, `errors`, `time`, `cost` and your scorer's metrics. Anything else, tokens included, is refused before a model is called. A contender missing a weighted value shows `-`, and one with errors cannot be named best. Without `weighted_score`, nothing changes.

#### Request types

`request_types` is required. It says what the suite's adapter sends. The types belong to the providers and show in `llm-evals --help`; a suite only names them:

| Type       | Provider                                 | Meaning                                              |
| ---------- | ---------------------------------------- | ---------------------------------------------------- |
| `prompt`   | OpenRouter (everything under `vendors:`) | a chat completion: system and user text in, text out |
| `typesafe` | `direct: typesafe:`                      | typed questions: noul, choice, score                 |

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
evals compare                            # everything the lineup lists, leaderboard only
evals compare                         # uses results.display
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

- `cases` prints one row per case: dataset, id, difficulty, the scorer's `summary`, word count.
- `verify` reports empty inputs and missing or unparsable `expected.json`, then runs `adapter.verify(dataset)` and `scorer.verify`.
- `run` and `compare` run one experiment per model and dataset, as many at once as the machine has CPUs. `-j N` / `--concurrency N` sets another limit, and `-j 0` starts them all together. `-p` is separate: the cases in flight inside each experiment.

Flags shared by `run` and `compare`: `-m/--models`, `-d/--dataset` (every dataset when omitted), `-c/--case`, `-e/--effort`, `-t/--temperature`, `--max-tokens`, `-p/--parallelism`, `-j/--concurrency`, `-C/--config FILE`, `--project NAME`, `--tracker NAME`, `--local`, `--no-open`, `-n/--dry-run`, `-o/--output [FILE]`, `--format tui|html|json`, `--totals overall|variant|both`, `--display none|tui|browser`, `--autosave/--no-autosave`, `--destination DIR` and `--temp-dir DIR`. `--totals` controls the TUI totals tables: the default `overall` compares contenders across all cases, `variant` compares each case folder (such as `complete` or `vague`) across datasets, and `both` prints both views. Completed runs are saved as timestamped JSON by default, independently of the selected display. Browser and TUI reports are rendered from that JSON; `--no-autosave` uses a temporary JSON snapshot under `temp_dir`. Use `llm-evals render results.json` to regenerate HTML from saved results without repeating model calls. `-l` and `-L` are reserved for logging and not yet implemented.

**Reading the output.** `results.display` selects no report, a terminal leaderboard, or a browser report. The TUI has one column per metric the scorer declares, ranked by the `primary` one, with a glossary built from each metric's `description`. Browser reports show global and dataset standings, sortable tables, case inputs, expected answers, scores and diagnostics. Provider names and model IDs use separate colors; the hero standings show effort and temperature next to the model. Every JSON snapshot records both parsed CLI options and effective run settings, including expanded model settings and selected cases. `render` turns a saved snapshot into HTML later. Progress bars and warnings go to STDERR, and anything a library prints while the bars redraw is saved to `log/<command>.warnings.<stamp>.log` instead of garbling the screen.

## Trackers

The gem always owns the run loop. A **tracker** decides where results go besides the terminal. The local JSON log always runs; at most **one remote tracker** runs beside it.

| Tracker      | Gems                                               | Key                  |
| ------------ | -------------------------------------------------- | -------------------- |
| local        | none                                               | none                 |
| `braintrust` | `braintrust`                                       | `BRAINTRUST_API_KEY` |
| `logfire`    | `opentelemetry-sdk`, `opentelemetry-exporter-otlp` | `LOGFIRE_TOKEN`      |

Choose one with `--tracker NAME`, or let its key select it (see selection order below). Braintrust also takes `BRAINTRUST_PROJECT_ID` or `--project`.

What each one sends:

- **local** writes `log/llm-evals/<experiment>.<stamp>.json`: settings, means, errors, usage, and one row per case (score, metrics, outcomes, diagnostics, error, usage).
- **braintrust** creates one experiment per run in the project, with one eval row per case: input, expected, output (or `_error`), the scorer's metrics as scores, and diagnostics, outcomes and usage as metadata. The experiment page opens when the run finishes, unless `--no-open`.
- **logfire** sends OTLP traces to `https://logfire-us.pydantic.dev/v1/traces` (`LOGFIRE_BASE_URL` for another region): one span per experiment (suite, project, model, provider, settings, case count, means) with one child span per case (id, dataset, variant, score, each metric, outcome counts, duration, tokens and cost, diagnostics as JSON cut at 4 KB, exceptions recorded). Raw replies are not sent unless the config has `logfire: { include_replies: true }`. There is no page to open.

**Selection order:** `--tracker NAME`, then `tracker:` in `.llm-evals.config.yml`, then the environment, where exactly one tracker's key being set selects it.

- Two keys set and nothing chosen is an error asking for `--tracker` or `tracker:`.
- `--local` (or `--tracker none`) means no remote tracker.
- A chosen tracker whose gem or key is missing fails before any model is called, naming both.
- `-v` prints which tracker was chosen and why.

Logfire has no Ruby gem of its own. It is an OTLP backend for the standard OpenTelemetry Ruby SDK, so the tracker builds its own tracer provider and exporter and leaves the global one alone. When `OTEL_EXPORTER_OTLP_ENDPOINT` or `OTEL_EXPORTER_OTLP_HEADERS` is already set, those win over `LOGFIRE_TOKEN`, and `-v` says so. Traces only: Logfire's metrics and logs SDKs are pre-1.0.

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
| `OPENROUTER_API_KEY`          | required for any `vendors:` model (OpenRouter)            |
| `TYPESAFE_API_KEY`            | required for a `direct: typesafe:` model                  |
| `BRAINTRUST_API_KEY`          | the braintrust tracker; selects it when nothing else does |
| `BRAINTRUST_PROJECT_ID`       | Braintrust project UUID; beats the lineup's `project`     |
| `LOGFIRE_TOKEN`               | the logfire tracker (a write token); selects it likewise  |
| `LOGFIRE_BASE_URL`            | Logfire region; default `https://logfire-us.pydantic.dev` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | when set, logfire uses it instead of `LOGFIRE_TOKEN`      |
| `OTEL_EXPORTER_OTLP_HEADERS`  | likewise                                                  |
| `LLM_EVALS_HELPER`            | a helper to load instead of searching upward              |

The suite's `env_files` load first, without overriding what is already exported. A missing key fails the run before any model is called, naming the variable.

## Writing a provider

A provider wraps one API: the request type it answers, the keys it needs, the models it lists, and `complete`.

- A provider that serves `vendors:` ids declares which ones with `prefix`.
- A `direct?` provider is reached only through a `direct:` key matching its `name`.
- Register it with `c.provider`. The last registered is asked first for a `vendors:` id; OpenRouter, which claims every id, is always asked last.

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

`Providers::TypeSafe` is a direct provider (`direct: typesafe:`, request type `typesafe`). It ships with TypeSafe's model list, key and pricing, which is enough for `verify` and the cost column. Its `complete` is not implemented yet and raises "no typesafe consumer yet": the typed request shape will be defined by the first suite that declares `request_types: [typesafe]`.

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
  # provider: nil for vendors:, a name for direct:.
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

# Build the .gem into pkg/; publish pushes it (RubyGems OTP from 1Password)
just build
just publish

# Install the pre-commit hooks
lefthook install
```

Specs build real directories under `Dir.mktmpdir` and never reach the network. `RubyLLM`, the Braintrust API classes and `Net::HTTP` are stubbed, and the trackers are asserted through OpenTelemetry's in-memory span exporter.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
