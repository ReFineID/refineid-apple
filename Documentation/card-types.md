# FINEID card types, by answer to reset

What DVV publishes about the cards it issues, and what our own card
actually answered. Source: *Technology note - ATR/ATS bytes* v1.0, DVV
ICT Unit / Pirinen Jari, 12.8.2024, read on 2026-07-27.

The point of keeping it here is the gap at the bottom: the note is two
years old and does not describe every card in circulation, so a lookup
built on it has to say "I do not know this one" rather than pick the
nearest row.

## Citizen eID cards

| Card | In production | Contact ATR |
|---|---|---|
| Thales MultiApp v5.0 (FINEID S4-1 v4.0) | 2023-03-13 -> | `3B 7F 96 00 00 80 31 B8 65 B0 85 05 00 11 12 24 60 82 90 00` |
| Gemalto MultiApp v4.2 (FINEID S4-1 v3.1) | 2021-01-11 - 2023-03-12 | `3B 7F 96 00 00 80 31 B8 65 B0 85 04 02 1B 12 00 F6 82 90 00` |
| Gemalto MultiApp v3.0 (FINEID S4-1 v3.0) | 2017-01-01 - 2021-01-10 | `3B 7F 96 00 00 80 31 B8 65 B0 85 03 00 EF 12 00 F6 82 90 00` |
| Setec SetCOS 5.1.X | legacy | `3B 7B 00 00 00 80 62 00 51 56 46 69 6E 45 49 44` |

The three MultiApp cards publish a contactless ATS of
`14 78 77 95 02` followed by the same historical bytes as their contact
ATR. Setec has no contactless interface.

## Social welfare, health care and organizational cards

| Card | In production | Contact ATR |
|---|---|---|
| Idemia Cosmo X (FINEID S1 v5.0) | ~2025 -> | `3B DD 96 00 80 31 FE 45 00 31 B8 64 04 29 EC C1 73 94 01 80 83 49` |
| Idemia ID.me IDeal Citiz 2.17-i (FINEID S1 v4.0) | 2019-12-17 -> | `3B DD 96 00 80 31 FE 45 00 31 B8 64 04 29 EC C1 73 94 01 80 82 48` |
| Oberthur Cosmo v7 IAS-ECC | ~2010 - 2019-12-16 | `3B DF 96 00 80 31 FE 45 00 31 B8 64 04 29 EC C1 73 94 01 80 82 90 00 00` |
| Segenmark FINEID | legacy | `3B 7B 18 00 00 80 62 01 54 56 46 69 6E 45 49 44` |

Contactless: Cosmo X answers `3B 89 80 01 00 31 B8 64 04 29 EC C1 73 94
01 80 83`, ID.me answers `3B 89 80 01 80 57 43 49 54 49 5A 32 31 91`,
and the other two have no contactless interface.

A Cosmo X organization card read here on 2026-08-07 confirmed the row:
the PC/SC-synthesized contactless answer was

    contactless   3B 8D 80 01 00 31 B8 64 04 29 EC C1 73 94 01 80 83 04

whose historical bytes are exactly the ones the note documents, so the
exact-match path names it. The certificate layout these cards publish is
FINEID S4-2 v4.0: the same EF.4331 authentication leaf and EF.4334 root
as S4-1, the issuing CA in EF.4333 rather than EF.4336, and the
signature leaf under DF.ESIGN (5016) rather than flat under the
application. The certificate slots list both homes and the card's
SELECT answer decides, so no table lookup gates the read.

## The card measured here does not appear above

Read on 2026-07-27 from an ACS ACR1581U, both interfaces of the same
card:

    contact       3B 7F 96 00 00 80 31 B8 65 B0 85 05 10 24 12 24 60 82 90 00
    contactless   3B 8F 80 01 80 31 B8 65 B0 85 05 10 24 12 24 60 82 90 00 22

Against the note's Thales MultiApp v5.0 row, two bytes differ:

    documented    80 31 B8 65 B0 85 05 00 11 12 24 60
    measured      80 31 B8 65 B0 85 05 10 24 12 24 60
                                       ^^ ^^

It is a v5 card: the generation byte is `05`, and the tail `12 24 60` is
the one the v5 row carries, where both Gemalto rows end `12 00 F6`. Only
the version and mask bytes differ, so this reads as a later revision of
the same platform than the one the note describes -- which is what the
note's date makes likely. Naming it "v5.0" on that evidence would be a
guess dressed as a fact.

## What this means for matching

Match on the historical bytes, not on the whole answer to reset. The
same card answers differently on each interface and through each reader:
a contact ATR frames them one way, a card's own ATS another, and a PC/SC
reader synthesizes a third (`3B 8F 80 01 ...` above). The historical
bytes are the part that identifies the card in all three.

Extract them by parsing the answer to reset as ISO 7816-3 defines it,
not by searching for the `80` category byte. The Idemia and Oberthur
rows above carry a `80` inside their interface bytes, and a search would
find that one first -- as one did while this table was being written.

Then: an exact match names the card; anything else falls back to the
generation byte for a family, says the variant is unrecognized, and
shows the answer to reset so the card can be added here. Only DVV can
turn the card measured above into an exact row.
