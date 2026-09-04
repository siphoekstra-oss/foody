# Masterprompt — Foody (iOS)

> Plak dit als eerste bericht in Claude Code, in de map `Foody/`.
> Sla het daarna op als `CLAUDE.md` in de repo-root zodat Claude Code het elke sessie meeneemt.

---

## 0. Rol

Je bent mijn senior iOS-engineer én mijn rem. Ik heb **minder dan 5 uur per week**. Elke regel code die niet bijdraagt aan de eerstvolgende mijlpaal is schade. Als ik om iets vraag dat buiten de huidige mijlpaal valt, zeg je dat en bouw je het niet.

Werk in kleine, werkende stappen. Na elke stap moet het project builden en draaien op een iPhone-simulator. Geen halve features, geen dode code, geen "dit maken we later af".

Als een aanname onduidelijk is: stel één concrete vraag en wacht. Ga niet gokken.

---

## 1. Wat we bouwen

**Foody** — een native iOS-app die live beschikbaarheid van de leukste, drukst bezette restaurants op één plek toont, en die je waarschuwt zodra er ergens een tafel vrijkomt.

De gebruiker kiest een **datum**, **middag of avond**, **gezelschapsgrootte** en ziet per restaurant welke tijden vrij zijn, gesorteerd op afstand. Tikken op een tijdslot opent de eigen boekingspagina van het restaurant met datum/tijd voorgevuld. Wij boeken niet zelf.

Daarnaast kan de gebruiker restaurants op een **watchlist** zetten met een datumvenster, en krijgt hij een melding zodra daar iets vrijkomt.

### Het segment — lees dit goed, het is niet "sterrenrestaurants"

Het gaat om **hoogwaardige hotspots**, niet om Michelin-gastronomie. Referentieniveau (door de opdrachtgever zelf genoemd):

| Restaurant | Plaats | Type |
|---|---|---|
| Nela | Amsterdam | live-fire, hotspot |
| Izakaya | Amsterdam | Aziatisch, Entourage Group |
| Ichi | Amsterdam | sushi/omakase |
| Kaiseki | Amsterdam | Japans |
| Tante Pietje | 's-Hertogenbosch | bistro |
| CoCo73 | 's-Hertogenbosch | food & drinks |
| Brasserie 155 | Vught | brasserie |
| L'Seven | Boxtel | restaurant |

Kenmerken van dit segment: €50-125 per persoon, sfeer en scene net zo belangrijk als het eten, vaak weken vooruit vol, en **grotendeels niet vermeld in Michelin of Gault&Millau**.

**Positionering (dit stuurt alle prioriteiten):** de enige serieuze concurrent, finediningfinder.nl, dekt uitsluitend gidsvermelde restaurants (Michelin, Gault&Millau, JRE, Relais & Châteaux) — ~900 stuks, ~633 met live beschikbaarheid, gratis, web-only, zonder app en zonder meldingen. Van de acht restaurants hierboven staat vrijwel geen enkele in dat universum. **Dit segment is dus daadwerkelijk onbediend.** Dat is de opening.

De tweede opening is de watchlist met push: die heeft niemand.

### De curatievraag (onopgelost, en het is geen technisch probleem)

Bij sterrenrestaurants bepaalt Michelin de lijst. Bij hotspots bestaat geen lijst. Wie besluit dat CoCo73 er wél in hoort en de zaak ernaast niet? Dat is redactioneel werk dat niet te automatiseren is. Behandel het als een handmatig onderhouden `restaurants.json` met expliciete opnamecriteria in een commentaarblok bovenaan, niet als iets dat een algoritme oplost.

### Expliciet buiten scope
- In-app boeken, betalingen, accounts, inloggen
- Android, iPad, watchOS, web
- Reviews, foto's van gerechten, menu's, chat
- Meerdere steden (later), heel Nederland (later)
- Alles wat een backend-database of gebruikersbeheer vereist

---

## 2. Harde beperkingen

| | |
|---|---|
| Ontwikkelaar | 1 persoon, < 5 uur/week |
| Infra-budget | ≈ €0/maand (GitHub Actions free tier, statische hosting) |
| Bestaand | Leeg SwiftUI-project `Foody` in Xcode, git al geïnitialiseerd |
| Doel M0 | Werkende app op mijn eigen telefoon binnen één weekend |
| Distributie | TestFlight, geen App Store-release in de eerste maanden |

Kies daarom **saai en standaard** boven slim: geen externe dependencies in de app tenzij ik er expliciet om vraag. `URLSession` + `Codable` + `SwiftUI` + `MapKit`/`CoreLocation` is genoeg.

---

## 3. De architectuur: één datacontract als ruggengraat

Alles draait om één JSON-bestand. De app kent alleen dít formaat en niets anders. In M0 zit het bestand in de app-bundle, in M1 komt het van een URL, in M2 wordt het door een crawler gevuld. **De app-code verandert daarbij niet.** Dat is het hele punt: ik kan de databron drie keer omgooien zonder de app aan te raken.

```json
{
  "generated_at": "2026-09-04T18:00:00Z",
  "schema_version": 1,
  "city": "amsterdam",
  "restaurants": [
    {
      "id": "rijks",
      "name": "Rijks",
      "cuisine": "Modern Dutch",
      "guides": { "michelin_stars": 1, "gaultmillau": 15.5, "bib": false },
      "price_indication_eur": 125,
      "lat": 52.3584,
      "lon": 4.8811,
      "address": "Museumstraat 2, Amsterdam",
      "website_url": "https://...",
      "image_url": "https://...",
      "booking_provider": "formitable",
      "booking_url": "https://...",
      "deeplink_template": "https://.../?date={date}&time={time}&covers={covers}",
      "status": "live",
      "last_checked": "2026-09-04T17:45:00Z",
      "availability": [
        {
          "date": "2026-09-12",
          "slots": [
            { "time": "12:15", "service": "lunch",  "max_covers": 4 },
            { "time": "19:30", "service": "dinner", "max_covers": 2 }
          ]
        }
      ]
    }
  ]
}
```

Regels:
- `status`: `live` (beschikbaarheid is echt opgehaald), `link_only` (we kennen alleen de boekingspagina), `unknown` (ophalen mislukt). De UI moet deze drie visueel onderscheiden — **nooit doen alsof `link_only` betekent "vol"**.
- `service` wordt afgeleid van de tijd: vóór 16:00 = `lunch`, daarna `dinner`. Zet het expliciet in de JSON, niet in de app-logica.
- `deeplink_template` gebruikt `{date}` (YYYY-MM-DD), `{time}` (HH:mm), `{covers}` (int). Als de provider geen voorgevulde link ondersteunt, is `deeplink_template` gelijk aan `booking_url`.
- Data ouder dan 60 minuten toont de app als "mogelijk verouderd" met het tijdstip van `last_checked`.
- Schema-wijzigingen verhogen `schema_version`; de app weigert onbekende hogere versies met een nette melding.

---

## 4. Mijlpalen

Bouw ze strikt op volgorde. Begin niet aan de volgende voordat de acceptatiecriteria van de vorige zijn afgevinkt en gecommit.

### M-1 — Handmatige survey, géén code (~1 uur, door mij zelf)
Voordat er een regel code komt, vul ik een spreadsheet met 40 doelrestaurants: naam, plaats, coördinaten, website, en **welk reserveringssysteem ze gebruiken** — af te lezen aan de URL achter de reserveerknop of aan het ingeladen widget-script.

Dit bepaalt alles wat daarna komt. Wat al bekend is uit een eerste steekproef:

| Restaurant | Systeem | Bron |
|---|---|---|
| Nela Amsterdam | SevenRooms | boekings-URL |
| Izakaya Amsterdam | SevenRooms (Entourage Group, meerdere zaken in één zoekopdracht) | boekings-URL |
| Tante Pietje | ingesloten widget, platform onbekend | `/reserveren/` pagina |
| Brasserie 155 (Vught) | **geen online reserveren** — telefoon en e-mail | website |
| CoCo73 Den Bosch | **geen online reserveren zichtbaar** — telefoon | website |

Harde conclusie hieruit: een deel van dit segment heeft helemaal geen online beschikbaarheid. Die restaurants krijgen `status: "link_only"` of vallen buiten de lijst. Als na de survey blijkt dat minder dan 25 van de 40 een aggregeerbaar systeem gebruikt, stoppen we en herzien we de regiokeuze in plaats van door te bouwen.

Acceptatiecriterium:
- [ ] `crawler/restaurants.json` bestaat, ingevuld, met per restaurant een `booking_provider` uit een vaste enum en een `provider_venue_id` waar bekend

### M0 — Werkende app op nepdata (~6-8 uur)
Geen netwerk, geen backend. `availability.json` in de app-bundle met de **40 echte restaurants uit de survey** (echte namen, adressen, coördinaten, boekingslinks) en verzonnen-maar-realistische tijdsloten voor de komende 30 dagen.

Schermen:
1. **Zoeken** — datumkiezer (vandaag t/m +60 dagen), segment middag/avond, stepper gezelschapsgrootte (1-8). Bovenaan sticky.
2. **Resultaten** — lijst met kaarten: naam, gidsvermelding (sterren/G&M), keuken, afstand in km, prijsindicatie, en een horizontaal scrollende rij tijdslot-chips. Gesorteerd op afstand, met een toggle naar "meeste beschikbaarheid".
3. **Detail** — restaurantinfo, alle tijden van de gekozen dag, knop "Openen op kaart", knop "Naar reserveringspagina".
4. **Leeg-staat** — als er niets vrij is: geen kille lege lijst, maar "Niets vrij op deze datum" + de eerstvolgende datum waarop dit restaurant wél iets heeft.

Acceptatiecriteria:
- [ ] Draait op mijn iPhone via Xcode, geen crashes
- [ ] Locatiepermissie netjes afgehandeld, met fallback op het centrum van Amsterdam bij weigering
- [ ] Datum/segment/aantal wijzigen ververst de lijst zonder haperen
- [ ] Tikken op een tijdslot opent Safari op de juiste voorgevulde URL
- [ ] Werkt in dark mode en met Dynamic Type
- [ ] Alle 40 restaurants hebben kloppende coördinaten en werkende boekingslinks

### M1 — Data van een URL (~2-3 uur)
Vervang de bundel-JSON door een `URLSession`-fetch van exact hetzelfde bestand, gehost als statisch bestand (GitHub Pages of Cloudflare Pages — gratis). Bundel-JSON blijft als offline fallback.

Acceptatiecriteria:
- [ ] App haalt bij opstarten op, cachet lokaal, en werkt offline op de cache
- [ ] Bij netwerkfout: gecachete data + duidelijke melding, geen lege app
- [ ] Ik kan de JSON op de server aanpassen en dat binnen een minuut in de app zien
- [ ] Geen enkele UI-wijziging nodig ten opzichte van M0

### M2 — Echte beschikbaarheid, één adapter (~10-15 uur)
Losse map `crawler/` in dezelfde repo. TypeScript of Python, draait als GitHub Actions cron elk half uur, schrijft `availability.json` naar de statische host.

**Welke provider adapter één wordt, bepaalt de survey uit M-1 — niet een aanname.** Wat we nu weten:

- In de *gidsvermelde* Nederlandse fine dining is Formitable ~30%, Zenchef ~25% (inmiddels één bedrijf), Guestplan ~16%, TheFork ~14%. Bron: analyse van finediningfinder.nl, één bron, zelf-gerapporteerd, niet onafhankelijk geverifieerd.
- In het *hotspot*-segment van deze app wijst de eerste steekproef op **SevenRooms** in Amsterdam (Nela, Izakaya en de rest van Entourage Group). Dat is een ander beeld dan de fine-dining-cijfers hierboven suggereren.

Kies de provider die na de survey de meeste van de 40 restaurants dekt. Bouw er precies één. De tweede adapter komt pas als M3 draait.

Architectuur van de crawler:
- `restaurants.json` — handmatig onderhouden bronbestand met de 40 restaurants en hun provider + provider-id
- `adapters/formitable.ts` — één functie: `fetchAvailability(restaurant, dateRange) → Slot[]`
- `adapters/index.ts` — registry, onbekende provider levert `status: "link_only"`
- `build.ts` — loopt alle restaurants af, roept de juiste adapter aan, schrijft het contract uit M3 weg

**Gedragsregels voor de crawler — niet onderhandelbaar:**
- Maximaal één verzoek per restaurant per 20 minuten
- Sequentieel met minimaal 2 seconden ertussen, nooit parallel hameren
- Herkenbare User-Agent met contactadres, bijvoorbeeld `FoodyBot/0.1 (+foody@voorbeeld.nl)`
- `robots.txt` respecteren
- Alleen lezen. Nooit een reservering aanmaken, wijzigen of vasthouden. Nooit tafels blokkeren.
- Bij 403/429: exponentiële backoff en dat restaurant 24 uur overslaan
- Geen persoonsgegevens opslaan, van niemand
- Faalt een adapter, dan `status: "unknown"` — nooit stilzwijgend oude data als vers presenteren

Acceptatiecriteria:
- [ ] Cron draait groen en produceert geldige JSON tegen `schema_version: 1`
- [ ] Minimaal 20 van de 40 restaurants op `status: "live"`
- [ ] Steekproef van 5 restaurants: de getoonde tijden kloppen met wat hun eigen site laat zien
- [ ] Crawler faalt zichtbaar (Actions rood) in plaats van stilletjes lege data te schrijven
- [ ] Geen enkele UI-wijziging nodig ten opzichte van M1

### M3 — Watchlist en meldingen (~8-10 uur) — dit is het eigenlijke product
- Gebruiker zet restaurants op een watchlist met een datumvenster en gezelschapsgrootte, lokaal opgeslagen
- Achtergrondverversing (`BGAppRefreshTask`) haalt de JSON op en vergelijkt met de vorige snapshot
- Nieuw slot binnen een gevolgd venster → lokale notificatie: "Er is een tafel vrijgekomen bij Rijks — vrijdag 12 september, 19:30"
- Tikken op de melding opent direct het detailscherm met dat slot

Bewust géén APNs-server in deze fase: lokale notificaties op basis van achtergrondverversing kosten nul infrastructuur. Nadeel is dat iOS de frequentie bepaalt — dat is een acceptabele beperking voor v1 en we meten of het in de praktijk snel genoeg is.

Acceptatiecriteria:
- [ ] Watchlist overleeft het afsluiten van de app
- [ ] Melding komt binnen bij een echt nieuw slot, en niet opnieuw voor een slot dat al gemeld is
- [ ] Geen melding als een slot alleen maar verdwijnt
- [ ] Notificatiepermissie wordt gevraagd op het moment dat de gebruiker zijn eerste watchlist maakt, niet bij het opstarten

### M4 — Uitbreiden (pas na echte gebruikers)
Guestplan-adapter, dan TheFork. Daarna extra steden. Elke uitbreiding is puur data plus één adapter — geen app-wijziging.

---

## 5. Codeafspraken

- Swift 6, iOS 17+, SwiftUI, geen storyboards
- Mappen: `Models/`, `Services/`, `Views/`, `Resources/`
- `AvailabilityStore` als enige `@Observable` bron van waarheid; views bevatten geen netwerk- of parseerlogica
- Alle datums intern in `Date`/`TimeZone(identifier: "Europe/Amsterdam")`; nooit met stringvergelijkingen rekenen
- Unit tests op: JSON-decodering (inclusief kapotte en onvolledige JSON), de lunch/diner-scheiding, de afstandsberekening, en de "wat is nieuw sinds vorige snapshot"-logica van M3
- Commit per afgeronde stap met een beschrijvende boodschap
- Geen SwiftData, geen CoreData, geen Firebase, geen analytics-SDK's in M0-M3

---

## 6. Waar dit misgaat (bouw hier tegen aan)

1. **Ongedocumenteerde endpoints breken.** Adapters zijn het fragielste deel. Bouw ze met een expliciete contracttest die faalt zodra het antwoordformaat verandert, zodat ik het merk voordat een gebruiker het merkt.
2. **Lege resultaten.** In het luxe segment is "vol" de normale toestand. Als de UI vooral "niets gevonden" toont, is de app dood. Toon daarom altijd de eerstvolgende beschikbare datum per restaurant, niet alleen de gevraagde.
3. **Verouderde data die vers lijkt.** Elke lijst toont het tijdstip van de laatste verversing. Liever "onbekend" dan een verkeerde belofte.
4. **Scope creep.** Ik ga vragen om filters, foto's, favorieten en een web-versie. Zeg nee tot M3 staat.
5. **Juridisch.** Het geautomatiseerd uitlezen van boekingswidgets kan in strijd zijn met de voorwaarden van die platformen. Ik ben geen jurist en dit is geen juridisch advies. De guardrails hierboven zijn bedoeld om het risico klein en het gedrag verdedigbaar te houden. Zodra er meer dan een handvol gebruikers is: mail de restaurants dat je ze gasten stuurt, en vraag de boekingsplatformen om een officiële partnerstatus.

---

## 7. Doorbouwen vanaf de telefoon

Ik wil vanaf mijn iPhone verder kunnen werken. Daarvoor moet dit project vanaf dag één op de commandline te bouwen zijn, want vanaf de telefoon is er geen Xcode-venster.

Lever daarom in M0 mee:

- `scripts/build.sh` — `xcodebuild -scheme Foody -destination 'platform=iOS Simulator,name=iPhone 16' build` met nette exit-code
- `scripts/test.sh` — `xcodebuild test` met dezelfde bestemming
- Beide moeten slagen op een schone clone

Regel voor elke sessie die vanaf de telefoon wordt gestuurd: na elke wijziging draai je `scripts/build.sh` en meld je het resultaat in één regel. Nooit code opleveren die je niet hebt gecompileerd.

## 8. Start hier

Doe nu, in deze volgorde:

1. Lees de bestaande projectstructuur en vertel me in vijf regels wat er staat.
2. Stel me **maximaal drie** vragen waarvan het antwoord de M0-implementatie echt verandert. Niet meer.
3. Zet daarna de complete M0 neer: modellen, store, drie schermen, en `availability.json` met 40 echte Amsterdamse restaurants.
4. Sluit af met: wat je gebouwd hebt, wat je bewust niet gebouwd hebt, en de eerste drie dingen die ik zelf moet controleren op mijn telefoon.

Voor de 40 restaurants: gebruik uitsluitend de lijst die ik in M-1 zelf heb ingevuld. Verzin geen namen, geen adressen en vooral **geen boekings-URL's** — een verzonnen reserveerlink is erger dan geen link, want die faalt pas als een gebruiker erop tikt. Ontbreekt een veld, zet dan `null` en meld het. Verzin wél de tijdsloten: die zijn in M0 expliciet nep, zichtbaar via een debug-badge die in M1 verdwijnt.

---
## 9. Afwijkingen en aanvullingen (besloten op 2026-09-04)

Vastgelegd zodat elke sessie dezelfde uitgangspunten heeft.

- **Regio M0 is Den Bosch, Vught en Boxtel**, niet Amsterdam. Fallback-locatie is de Markt in 's-Hertogenbosch (51.6886843, 5.3036562). Amsterdam wordt de eerste uitbreiding in M4.
- **Geen nepdata.** M0 draait op een echte crawler-snapshot in de bundel (`source: "crawler"`); de M2-crawler is naar voren gehaald. De debug-badge uit M0 bestaat daarom niet.
- **Contract v1, aanvullingen:** `phone` (E.164, nullable) per restaurant; `source` op documentniveau; per dag optioneel `services_available: ["lunch"|"dinner"]` voor systemen die alleen op dag-niveau "vrij" melden zonder tijden. De app toont dat als "Vrij in de avond, kies je tijd op de reserveringspagina". Een status die de app niet kent, wordt `unknown`.
- **Providers in deze regio:** Zenchef (Brasserie 155, L'Seven) geeft met één leesverzoek per restaurant alle tijdsloten met mogelijke gezelschapsgroottes; deeplinks met `rid`, `pax` en `day` zijn in de browser gecontroleerd. Guestplan (Tante Pietje, CoCo73) geeft per maand alleen dag-niveau per dienst en per dag alleen tijden voor één gezelschapsgrootte. Standaard halen we bij Guestplan alleen dag-niveau op (één verzoek per maand); `provider_meta.detail_days` zet tijdsloten voor de eerste dagen aan tegen één extra verzoek per dag. De publieke Guestplan-pagina is `https://widget.guestplan.com/?i=<accessKey>&partySize={covers}`; een datumparameter is daar niet geverifieerd.
- **robots.txt:** `widget.guestplan.com` verbiedt alle bots en wordt niet aangeroepen; `bookings.zenchef.com` verbiedt alleen genoemde bots; de API-hosts publiceren geen robots.txt. De crawler controleert dit per host bij elke run.
- **Bouwen:** `scripts/build.sh` en `scripts/test.sh` kiezen automatisch een iPhone-simulator (`FOODY_SIMULATOR` overschrijft). Swift 6-taalmodus met `nonisolated` als standaard-isolatie; iOS 17.0; alleen iPhone.
