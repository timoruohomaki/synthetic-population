# Source data

The generator combines five open data sets. They are **not** in the repository
(about 500 MB, and some have their own terms of use): download them into this
folder. File names are matched by pattern (see `sources:` in `../config.yaml`),
so newer versions work as long as the name pattern and format stay the same.
When several versions are present, the newest file wins.

| What | File name pattern | Publisher and where to get it |
|------|-------------------|-------------------------------|
| First names with counts | `etunimitilasto-*.xlsx` | Digital and Population Data Services Agency (DVV): [Väestötietojärjestelmän suomalaisten nimiaineistot](https://www.avoindata.fi/data/fi/dataset/none), CC BY 4.0 |
| Last names with counts | `sukunimitilasto-*.xlsx` | Same DVV data set as above |
| Building addresses | `Suomi_osoitteet_*.OPT` | DVV: *Rakennusten osoitetiedot ja äänestysaluetiedot - koko Suomi* on avoindata.fi, also mirrored at [nic.funet.fi/index/geodata/dvv/osoitteet](https://nic.funet.fi/index/geodata/dvv/osoitteet/). Unzip the `.OPT` file here. The record description PDF is useful to keep alongside (`DVV-kuvaus.pdf`). |
| Postcodes | `PCF_*.dat` | Posti: [Postinumeroaineistot](https://www.posti.fi/webpcode/), file *PCF*. Free of charge; read and follow Posti's terms of use. Record description: `PCF_Description_Finnish.pdf` from the same page. |
| Municipalities | `kunta_1_*.csv` | Statistics Finland: [Kunnat 2026](https://stat.fi/fi/luokitukset/kunta/kunta_1_20260101), "Lataa" → CSV |

`../reference/regions_dvv.csv` (region codes 01-19 as used in the DVV address
file) is small and ships with the repository.

## Formats in short

- **Name files**: one sheet per group. First names: `Miehet ens`, `Naiset ens`
  (first given name) and `Miehet muut`, `Naiset muut` (second and later given
  names), columns *Etunimi* and *Lukumäärä*. Last names: sheet `Nimet`,
  columns *Sukunimi* and *Yhteensä*. Names used by fewer than five people are
  not published.
- **Address file**: semicolon separated, ISO 8859-1 (latin1), no header,
  16 fields, about 3,9 million rows; one row per address of a building. Only
  residential buildings (usage code 1) with a street, number and postcode are
  used, about 2,0 million addresses.
- **PCF**: fixed width, ISO 8859-1, one `PONOT` record per postcode with
  Finnish and Swedish post office names and the language of the municipality.
- **Municipalities**: semicolon separated UTF-8 with codes like `'091'`.

## Cache

The first run cleans the address file (10-20 seconds) and saves the result to
`cache/` as RDS. Delete the folder to force a rebuild; a new address or
postcode file gets its own cache file automatically.
