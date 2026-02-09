# App Blueprint: Eerste Stapjes

## Overzicht

Eerste Stapjes is een mobiele applicatie gebouwd met Flutter, ontworpen om de groei en ontwikkeling van kinderen vast te leggen en te bewaren. Gebruikers kunnen inloggen met hun Google-account en vervolgens individuele profielen aanmaken voor hun kinderen. Voor elk profiel kan de gebruiker een visuele tijdlijn creëren door dagelijks een foto toe te voegen. De app maakt intensief gebruik van Firebase voor backend-services, waaronder authenticatie, dataopslag en bestandsopslag.

---

## Geïmplementeerde Features, Stijl & Design

### Architectuur & Technologie

- **Framework:** Flutter
- **Backend:** Firebase
  - **Authenticatie:** Firebase Auth (geïntegreerd met Google Sign-In).
  - **Database:** Cloud Firestore voor het opslaan van gebruikersdata, profielinformatie en metadata van de dagelijkse entries.
  - **Opslag:** Firebase Storage voor het hosten van profielfoto's en de dagelijkse foto-uploads.
- **State Management:** `provider` package wordt gebruikt voor het beheren van de app-status, zoals de profiel-data.
- **Navigatie:** Standaard Flutter `MaterialPageRoute` navigatie.

### Kernfunctionaliteiten

1.  **Gebruikersauthenticatie:**
    - Veilige login via Google Sign-In.
    - De app-status reageert op de login- en logout-status van de gebruiker.

2.  **Profielbeheer:**
    - Gebruikers kunnen meerdere profielen aanmaken, bekijken en bijwerken.
    - Elk profiel bevat:
      - Een unieke ID
      - Naam
      - Geboortedatum (selecteerbaar via een date picker)
      - Een profielfoto (te kiezen uit de galerij van het toestel).

3.  **Dagelijkse Momenten (Entries):**
    - Gebruikers kunnen een foto toevoegen voor een specifieke datum binnen een profiel.
    - De app biedt de mogelijkheid om een foto als 'favoriet' te markeren.

### User Interface (UI) & User Experience (UX)

- **Design Stijl:** Material Design 3.
- **Thema:**
  - De app ondersteunt zowel een lichte als een donkere modus (`lightTheme` en `darkTheme`).
  - De themabestanden zijn gecentraliseerd in `lib/theme.dart`.
- **Schermen:**
  - **`ProfileSelectionScreen`:** Toont een grid-view van alle aangemaakte profielen. Bevat een prominente knop om een nieuw profiel aan te maken.
  - **`CreateProfileScreen`:** Een formulier voor het aanmaken of bewerken van een profiel. Inclusief een `ImagePicker` voor de profielfoto en een `DatePicker` voor de geboortedatum.
  - **`CalendarScreen`:** Een kalenderweergave (`table_calendar`) waarin gebruikers kunnen navigeren om de foto's per dag te bekijken.
- **Componenten & Packages:**
  - `image_picker`: Voor het selecteren van afbeeldingen uit de galerij.
  - `table_calendar`: Voor de weergave van de kalender.
  - `intl`: Voor het formatteren van datums (bijv. in 'nl_NL' formaat).
  - `provider`: Voor state management.

### Debugging & Oplossingen

- **Build Fout (`ThemeProvider`):** Een initiële build-fout is opgelost door de `ThemeData` definities te verplaatsen naar een apart `theme.dart` bestand en dit correct te importeren.
- **Build Fout (Lettertype):** Een fout door een ontbrekend `Pacifico` lettertype is opgelost door de verwijzing naar het custom lettertype tijdelijk uit `pubspec.yaml` te verwijderen om de build te laten slagen.
- **Runtime Fout (`firebase_storage/object-not-found`):** Een bug bij het uploaden van profielfoto's is opgelost. De code wacht nu correct tot de upload naar Firebase Storage is voltooid alvorens de download-URL op te vragen. Dit loste de race-conditie op.

---

## Huidig Plan

- **Status:** Bezig met het updaten van het login scherm.
- **Acties:**
    - De titel op het loginscherm aanpassen naar "Eerste stapjes".
    - De subtekst aanpassen naar "Elke dag een stapje verder.".
    - Het "voetjes png.png" logo toevoegen.
    - De "voetjes-animatie-final.html" animatie toevoegen.
