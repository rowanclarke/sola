#!/usr/bin/env python3
"""
Enrich translations.json with BCP 47 language subtags.

Downloads the IANA Language Subtag Registry, resolves each translation's
ISO 639-3 code to its BCP 47 subtag, and writes the result back into
translations.json. Also generates assets/language_subtags.json.
"""

import json
import os
import re
import urllib.request

REGISTRY_URL = "https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
TRANSLATIONS_PATH = os.path.join(PROJECT_ROOT, "assets", "translations.json")
SUBTAGS_OUTPUT_PATH = os.path.join(PROJECT_ROOT, "assets", "language_subtags.json")

# Script name to BCP 47 script subtag mapping
SCRIPT_TO_SUBTAG = {
    "Latin": "Latn",
    "Arabic": "Arab",
    "Cyrillic": "Cyrl",
    "Devanagari": "Deva",
    "Bengali": "Beng",
    "Gurmukhi": "Guru",
    "Gujarati": "Gujr",
    "Oriya": "Orya",
    "Tamil": "Taml",
    "Telugu": "Telu",
    "Kannada": "Knda",
    "Malayalam": "Mlym",
    "Sinhala": "Sinh",
    "Thai": "Thai",
    "Lao": "Laoo",
    "Tibetan": "Tibt",
    "Myanmar": "Mymr",
    "Georgian": "Geor",
    "Hangul": "Kore",
    "Ethiopic": "Ethi",
    "Cherokee": "Cher",
    "Khmer": "Khmr",
    "Armenian": "Armn",
    "Greek": "Grek",
    "Hebrew": "Hebr",
    "Chinese": "Hans",
    "Japanese": "Jpan",
    "Korean": "Kore",
    "Coptic": "Copt",
    "Thaana": "Thaa",
    "Nko": "Nkoo",
    "Vai": "Vaii",
    "Tifinagh": "Tfng",
    "Balinese": "Bali",
    "Javanese": "Java",
    "Ol Chiki": "Olck",
}

# Hardcoded fallbacks for ISO 639-3 codes whose lang_en is in non-Latin script
# or where the IANA description doesn't match lang_en
HARDCODED_FALLBACKS = {
    "eng": "en",
    "fra": "fr",
    "deu": "de",
    "spa": "es",
    "por": "pt",
    "ita": "it",
    "nld": "nl",
    "rus": "ru",
    "pol": "pl",
    "ces": "cs",
    "slk": "sk",
    "hun": "hu",
    "ron": "ro",
    "bul": "bg",
    "hrv": "hr",
    "srp": "sr",
    "slv": "sl",
    "ukr": "uk",
    "bel": "be",
    "lit": "lt",
    "lav": "lv",
    "est": "et",
    "fin": "fi",
    "swe": "sv",
    "nor": "no",
    "dan": "da",
    "isl": "is",
    "gle": "ga",
    "cym": "cy",
    "eus": "eu",
    "cat": "ca",
    "glg": "gl",
    "tur": "tr",
    "aze": "az",
    "kaz": "kk",
    "uzb": "uz",
    "tuk": "tk",
    "tat": "tt",
    "kir": "ky",
    "tgk": "tg",
    "ara": "ar",
    "heb": "he",
    "fas": "fa",
    "urd": "ur",
    "hin": "hi",
    "ben": "bn",
    "pan": "pa",
    "guj": "gu",
    "ori": "or",
    "tam": "ta",
    "tel": "te",
    "kan": "kn",
    "mal": "ml",
    "sin": "si",
    "nep": "ne",
    "mar": "mr",
    "asm": "as",
    "mya": "my",
    "tha": "th",
    "lao": "lo",
    "khm": "km",
    "vie": "vi",
    "zho": "zh",
    "cmn": "cmn",
    "jpn": "ja",
    "kor": "ko",
    "ind": "id",
    "msa": "ms",
    "tgl": "tl",
    "jav": "jv",
    "sun": "su",
    "kat": "ka",
    "hye": "hy",
    "ell": "el",
    "mkd": "mk",
    "sqi": "sq",
    "bos": "bs",
    "afr": "af",
    "swa": "sw",
    "amh": "am",
    "hau": "ha",
    "yor": "yo",
    "ibo": "ig",
    "mlg": "mg",
    "som": "so",
    "zul": "zu",
    "xho": "xh",
}


def download_registry():
    """Download the IANA Language Subtag Registry."""
    print(f"Downloading IANA registry from {REGISTRY_URL}...")
    req = urllib.request.Request(REGISTRY_URL, headers={"User-Agent": "sola-enrich/1.0"})
    with urllib.request.urlopen(req) as resp:
        data = resp.read().decode("utf-8")
    print(f"Downloaded {len(data)} bytes")
    return data


def parse_registry(data):
    """Parse the IANA registry into a lookup of language subtags.

    Returns:
        subtag_lookup: dict mapping subtag -> {description, suppress_script, scope}
        description_lookup: dict mapping lowercase description -> subtag
        all_languages: list of all language records
    """
    records = data.split("%%")
    subtag_lookup = {}
    description_lookup = {}
    all_languages = []

    for record in records:
        lines = record.strip().split("\n")
        fields = {}
        current_key = None
        for line in lines:
            if ":" in line and not line.startswith(" "):
                key, _, value = line.partition(":")
                key = key.strip()
                value = value.strip()
                if key == "Description":
                    # Can have multiple Description fields
                    if "Description" in fields:
                        if isinstance(fields["Description"], list):
                            fields["Description"].append(value)
                        else:
                            fields["Description"] = [fields["Description"], value]
                    else:
                        fields["Description"] = value
                else:
                    fields[key] = value
                current_key = key
            elif line.startswith(" ") and current_key:
                # Continuation line
                if current_key == "Description":
                    if isinstance(fields.get("Description"), list):
                        fields["Description"][-1] += " " + line.strip()
                    else:
                        fields["Description"] = fields.get("Description", "") + " " + line.strip()
                else:
                    fields[current_key] = fields.get(current_key, "") + " " + line.strip()

        if fields.get("Type") == "language" and "Subtag" in fields:
            subtag = fields["Subtag"]
            desc = fields.get("Description", "")
            if isinstance(desc, list):
                descriptions = desc
                desc = desc[0]
            else:
                descriptions = [desc]

            entry = {
                "subtag": subtag,
                "description": desc,
                "suppress_script": fields.get("Suppress-Script", ""),
                "scope": fields.get("Scope", ""),
            }
            subtag_lookup[subtag] = entry

            for d in descriptions:
                description_lookup[d.lower()] = subtag

            all_languages.append(entry)

    print(f"Parsed {len(all_languages)} language subtags")
    return subtag_lookup, description_lookup, all_languages


def resolve_bcp47(code, lang_en, subtag_lookup, description_lookup):
    """Resolve an ISO 639-3 code to its BCP 47 subtag."""
    # Direct match in IANA registry
    if code in subtag_lookup:
        return code

    # Check hardcoded fallbacks
    if code in HARDCODED_FALLBACKS:
        return HARDCODED_FALLBACKS[code]

    # Try matching by language name against descriptions
    lang_lower = lang_en.lower().strip()
    if lang_lower in description_lookup:
        return description_lookup[lang_lower]

    # Try partial match - check if lang_en starts with a description
    for desc, subtag in description_lookup.items():
        if lang_lower == desc or desc.startswith(lang_lower):
            return subtag

    # Fall back to the original code (it may be a valid 3-letter BCP 47 subtag)
    return code


def build_bcp47_tag(subtag, script, subtag_lookup):
    """Build the full BCP 47 tag with optional script subtag."""
    entry = subtag_lookup.get(subtag)
    suppress_script = entry.get("suppress_script", "") if entry else ""

    # Map the script name to BCP 47 script subtag
    script_subtag = SCRIPT_TO_SUBTAG.get(script, "")

    if script_subtag and suppress_script != script_subtag:
        return f"{subtag}-{script_subtag}"
    return subtag


def main():
    # Download and parse the IANA registry
    registry_data = download_registry()
    subtag_lookup, description_lookup, all_languages = parse_registry(registry_data)

    # Load translations.json
    print(f"Loading translations from {TRANSLATIONS_PATH}...")
    with open(TRANSLATIONS_PATH, "r", encoding="utf-8") as f:
        translations = json.load(f)
    print(f"Loaded {len(translations)} translations")

    # Enrich each translation
    resolved_count = 0
    for t in translations:
        code = t.get("code", "")
        lang_en = t.get("lang_en", "")
        script = t.get("script", "")

        bcp47 = resolve_bcp47(code, lang_en, subtag_lookup, description_lookup)
        bcp47_tag = build_bcp47_tag(bcp47, script, subtag_lookup)

        t["bcp47"] = bcp47
        t["bcp47_tag"] = bcp47_tag

        if bcp47 != code:
            resolved_count += 1

    print(f"Resolved {resolved_count} codes to different BCP 47 subtags")

    # Write enriched translations.json
    print(f"Writing enriched translations to {TRANSLATIONS_PATH}...")
    with open(TRANSLATIONS_PATH, "w", encoding="utf-8") as f:
        json.dump(translations, f, indent=2, ensure_ascii=False)
    print("Done writing translations.json")

    # Generate language_subtags.json
    print(f"Writing {len(all_languages)} language subtags to {SUBTAGS_OUTPUT_PATH}...")
    with open(SUBTAGS_OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(all_languages, f, indent=2, ensure_ascii=False)
    print("Done writing language_subtags.json")

    print("\nEnrichment complete!")
    print(f"  - translations.json: {len(translations)} entries with bcp47 and bcp47_tag fields")
    print(f"  - language_subtags.json: {len(all_languages)} language subtags")


if __name__ == "__main__":
    main()
