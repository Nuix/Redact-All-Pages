Redact All Pages
================

![Last tested in Nuix 7.4](https://img.shields.io/badge/Nuix-7.4-green.svg)

View the GitHub project [here](https://github.com/Nuix/Redact-All-Pages) or download the latest release [here](https://github.com/Nuix/Redact-All-Pages/releases).

# Overview

**Written By:** Jason Wells

Applies full page redactions to all pages present in a given collection of items.  Items redacted are determined by selecting a tag which is applied to those items.

# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

## Settings

| Setting                     | Description                                                                                                  |
|-----------------------------|--------------------------------------------------------------------------------------------------------------|
| **Create New Markup Set**   | When selected, script will create a new markup set to contain the redactions it creates.                     |
| **New Markup Set Name**     | Determines the name of markup set when **Create New Markup Set** is selected.                                |
| **Description**             | Determines the description of markup set when **Create New Markup Set** is selected.                         |
| **Redaction Reason**        | Determines the redaction reason of markup set when **Create New Markup Set** is selected.                    |
| **Use Existing Markup Set** | Specifies redactions should be added to existing markup set (only available when markup sets already exist). |
| **Markup Set**              | Specifies markup set to use when **Use Existing Markup Set** is selected.                                    |
| **Tag Name**                | Tag used to locate items which will have full page redactions applied.                                       |

## Modifying Redaction Region

You can choose a different size for the redaction applied by editing the following variables at the top of the script:

- `redaction_x`
- `redaction_width`
- `redaction_y`
- `redaction_height`

These values are defined as a percentage of the page with `0.0` being 0% and `1.0` being 100%.

```
    (x, y) -------------------------------------- (x + width, y)
    |                                                          |
    |                                                          |
 H  |                                                          |
 E  |                                                          |
 I  |                    Redaction Region                      |
 G  |                                                          |
 H  |                                                          |
 T  |                                                          |
    |                                                          |
 ↓  |                                                          |
    (x, y + height)--------------------- (x + width, y + height)

                              WIDTH →
```

These values denote the entire page edge to edge:

```ruby
redaction_x = 0.0
redaction_width = 1.0
redaction_y = 0.0
redaction_height = 1.0
```

These values would redact the top half of each page:

```ruby
redaction_x = 0.0
redaction_width = 1.0
redaction_y = 0.0
redaction_height = 0.5
```

These values would redact the bottom half of each page:
```ruby
redaction_x = 0.0
redaction_width = 1.0
redaction_y = 0.5
redaction_height = 0.5
```

## Concurrency

This script uses multiple threads to apply redactions.  The number of threads used is configured with this variable:

```ruby
concurrency = 4
```

**Note:** More threads is not always better and may actually decrease overall throughput.

# License

```
Copyright 2018 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
