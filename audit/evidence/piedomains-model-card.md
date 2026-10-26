---
license: mit
library_name: transformers
pipeline_tag: text-classification
tags: [website-classification, multilingual, modernbert]
base_model: jhu-clsp/mmBERT-base
---

# piedomains-text

Classifies a website into one of 44 content categories from its homepage text. The default
model in [`piedomains`](https://github.com/themains/piedomains).

**0.818 accuracy / 0.758 macro-F1** on 4,382 held-out documents.
Temperature-scaled: T = 1.2483, ECE 0.0490 to 0.0168.

## Splits are a pure function of the domain

`sha256(domain) % 100` decides train/val/test. No seed, no shuffle, no ordering. Every
script computes the same answer for the same domain, so the text corpus and the screenshot
corpus cannot disagree about where a domain belongs, and anyone can recompute what this
model trained on without being told.

That replaced six leak detectors. They existed because two preparers each shuffled their
own list, and three separate times a model here was scored on its own training data --
image-only read 0.768 where the honest figure was 0.429, and text read 0.9357 against a
real 0.71. Each looked plausible for a while.

## The label set is 44, and two of them are not topics

`parked` (F1 0.987) and `unavailable`
(F1 0.915, precision
1.000) mean *the domain resolves but there is no
site*: a for-sale placeholder, a server autoindex, a suspended account. They are categories
rather than errors because the page states them plainly, and because leaving them out put
dead pages inside topic classes.

## Known defect: `drugs` absorbs retail

Extracting those two classes did not finish the job, and the shipped model still gets this
wrong. Only **28% of the 672 `drugs` training documents mention any drug or pharmacy term**
(against 4% of `shopping`). The rest are expired pharmacy domains recycled into SEO spam,
plus parked and dead pages the extraction missed -- one advertises the Squadhelp domain
marketplace, another says "blog not found".

So `drugs` learned "product listings and prices" rather than "drugs", and it competes with
retail. Live, today:

| domain | prediction | |
|---|---|---|
| `walmart.com` | **drugs 0.56** | `shopping` only 0.14 |
| `zappos.com` | **drugs 0.40** | a shoe catalogue |
| `amazon.com` | shopping 0.37 | `drugs` second at 0.20 |
| `rei.com` | sports 0.20 | `drugs` second at 0.17 |

`drugs` is in the top two for four of five retailers tested. Treat a `drugs` label on a
commercial site as unreliable. The fix is a labelling pass, not more data.

## It is not mutually exclusive, deliberately

Four questions share one vocabulary, and the error rate tracks the axis rather than the
class: status ~1%, topic ~15%, risk ~21%, and the labels describing what a site *is*
(`shopping`, `news`, `forum`) ~31%. `shopping` says what a site does and `automobile` says
what it is about; a car dealership is honestly both.

So the library returns a `categories` list -- every label above a threshold -- alongside the
argmax. That lifts the chance of reporting the right label from 81.8% to 87.3% at 1.30
labels per domain. **Read that as recall.** The evaluation gold is single-label, so nothing
here establishes whether a *second* label is correct.

## Weakest classes, named

`urlshortener` 0.154,
`library` 0.333,
`socialnet` 0.372,
`shopping` 0.453. The first three sit at their ceiling in
the corpus -- more data is not available for them. `shopping` is different: it has tens of
thousands of unused documents and still fails, because it is competing against topics
rather than being one.
