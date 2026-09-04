# Crawler

Leest per restaurant de beschikbaarheid uit het reserveersysteem en schrijft `availability.json`
(schema_version 1, zie `CLAUDE.md`). De app kent alleen dat bestand.

```bash
python3 crawler/build.py                 # schrijft Foody/Resources/availability.json
python3 crawler/build.py --out out.json --days 30
python3 -m unittest discover -s crawler/tests -t crawler
```

Exit-codes: `0` alles live, `2` minstens één restaurant `unknown` (adapter of netwerk faalde; het
eerlijke bestand is wél geschreven), `1` bestand geweigerd door de contractcontrole.

## Gedragsregels (niet onderhandelbaar, zie CLAUDE.md §M2)

- Alleen lezen. Nooit een reservering aanmaken, wijzigen of vasthouden.
- User-Agent `FoodyBot/0.1 (+foody@voorbeeld.nl)`; vervang het contactadres door een echt adres.
- Sequentieel, minimaal 2 seconden tussen verzoeken (`http_client.py`).
- `robots.txt` per host wordt opgehaald en gerespecteerd; `widget.guestplan.com` verbiedt bots en wordt
  daarom nooit aangeroepen, de API-hosts (`bookings-middleware.zenchef.com`, `api.guestplan.com`)
  publiceren geen robots.txt.
- Bij 403/429: restaurant 24 uur overslaan (`crawler/.cache/skip.json`), 5xx en netwerkfouten met
  exponentiële backoff (2, 4, 8 s).
- Geen persoonsgegevens: van Guestplan wordt alleen het account-id bewaard, niet de contactgegevens
  die `/v1/restaurants` meegeeft.
- Faalt een adapter, dan `status: "unknown"`; oude data wordt nooit als vers gepresenteerd.

## Verzoeken per run

| Provider  | Verzoeken per restaurant | Levert |
|-----------|--------------------------|--------|
| Zenchef   | 1 (`getAvailabilities` over het hele bereik) | tijdsloten met mogelijke gezelschapsgroottes |
| Guestplan | 1 per kalendermaand in het bereik (meestal 2) | per dag "vrij" per dagdeel, zonder tijden (`services_available`) |
| Guestplan met `provider_meta.detail_days = N` | + N | tijdsloten voor de eerste N beschikbare dagen, gezelschap van 2 |

Plus één `robots.txt`-verzoek per host per run.

## Een restaurant toevoegen

Vul `restaurants.json` aan (criteria staan bovenin). Zenchef: `provider_venue_id` is de `rid` uit de
boekings-URL of `data-restaurant` van de widget. Guestplan: `provider_venue_id` is de access key uit de
restaurantsite (`_gstpln.accessKey`), `provider_account_id` komt uit `GET /v1/restaurants`, en
`provider_meta.services` lees je af uit één dagdetail (dienst-id's vóór 16:00 zijn lunch, daarna diner);
onbekende id's logt de crawler als waarschuwing.
