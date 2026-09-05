# UNTDED 2005 — digitalized dataset

Machine-readable edition of the **United Nations Trade Data Elements
Directory 2005** (ECE/TRADE/362, published in parallel as
**ISO 7372:2005**): **1504 trade data elements** (tags 1000–9649) as a
YAML single source of truth, with typed models, validation, and
content-fidelity verification.

## Mandate

This work is carried out on behalf of **UN/CEFACT (UNECE)** and
**ISO/TC 154** (Processes, data elements and documents in commerce,
industry and administration), per **ISO/TC 154 N1727** — resolutions of
the 45th plenary meeting, DIN Berlin, 2026-08-31/09-04, all approved by
6 P-members (DIN, SAC, BSI, JISC, UNI, KATS):

- **Resolution P-2026-07** (JWG 9) — *"Encouragement for exploring the
  use of an open-source platform to support the maintenance and
  publication of ISO 7372."* ISO 7372 is the TDED/UNTDED standard; this
  repository is that open-source platform's dataset core.
- **Resolution P-2026-06** (JWG 9) — additional ISO- and UNECE-side
  expert support for ISO 7372's **timely publication before October
  2028**.
- **Resolution P-2026-01** (JWG 1) — meeting with the UNECE Secretariat
  on the stalled maintenance/publication of the UN/EDIFACT Directories
  (D.25A severely delayed); this dataset demonstrates a working
  alternative path.

## Layout

```
model/    Untded::* — lutaml-model classes + Extractor, Validator,
          Verifier, Exporter, OcrSampler (Ruby, no Python)
data/     YAML SSOT
  elements/1000-1699.yaml … 9000-9699.yaml   # 9 TDED categories
  review-queue.yaml
bin/      extract, validate, export, verify, crosscheck-edifact
spec/     RSpec — real PDF + real data, no mocks
```

The source PDFs, front-matter OCR, section 4.1 legend, and the
UN/EDIFACT D.05B cross-check corpus live in the sibling
[`untded/references`](https://github.com/untded/references) repository
(default path `../references`, override with `UNTDED_REFERENCES_DIR`).

## Commands

```bash
bundle install
bin/extract && bin/validate && bin/export      # SSOT pipeline
bin/verify                                     # content-fidelity checks
bin/verify --ocr 60                            # + independent re-OCR sample
bin/crosscheck-edifact                         # join vs D.05B mirror
bundle exec rspec
```

## Attribution

Content source: **UNTDED 2005**, ECE/TRADE/362, © United Nations /
UNECE. Digitized and verified by this project; reproduced with
attribution. See `README` verification section in the dataset docs and
the website's `/method/` page for the full verification record
(character conservation 169,020 chars exact; 1504 UID words = 1504
elements; OCR re-read agreement; D.05B cross-check).
