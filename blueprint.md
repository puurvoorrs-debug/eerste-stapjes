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

2.  **Profielbeheer & Rollen:**
    - **Ouder/Verzorger (Eigenaar):** Kan profielen aanmaken, bewerken, verwijderen en delen via een unieke code.
    - **Volger:** Kan een profiel volgen met de unieke code en heeft alleen-lezen toegang.
    - Profielen worden opgeslagen in een centrale `profiles` collectie om delen mogelijk te maken.

3.  **Dagelijkse Momenten (Entries):**
    - Eigenaren kunnen dagelijks een foto toevoegen aan een profiel.
    - Zowel eigenaren als volgers kunnen foto's als 'favoriet' markeren. Deze favorieten zijn per gebruiker opgeslagen.

### User Interface (UI) & User Experience (UX)

- **Design Stijl:** Material Design 3.
- **Thema:** Ondersteuning voor lichte en donkere modus.
- **Schermen:**
  - **`ProfileSelectionScreen`:** Toont een gescheiden weergave van 'Mijn Profielen' en 'Gevolgde Profielen'. Bevat knoppen om een nieuw profiel te maken of een bestaand profiel te volgen.
  - **`CreateProfileScreen`:** Formulier voor het aanmaken/bewerken van profielen.
  - **`CalendarScreen`:** Kalenderweergave van de dagelijkse foto's. Eigenaren zien hier een 'Deel' knop om de profielcode te kopiëren.

### Debugging & Oplossingen

- **Diverse Build & Runtime Fouten:** Opgelost tijdens de initiële ontwikkeling.
- **Data Structuur:** Gemigreerd van een geneste (`users/{uid}/profiles`) naar een centrale (`profiles`) datastructuur om het delen van profielen te faciliteren.

---

## Huidig Plan

- **Status:** Bugfixes en Feature Verbetering.
- **Doel:** De layout van het profielselectiescherm corrigeren en de favorieten-functionaliteit aanpassen.
- **Acties:**
    1.  **Layout Fix (`ProfileSelectionScreen`):**
        - Het probleem waarbij de profiellijst niet correct gecentreerd is en avatars worden afgesneden, wordt opgelost.
        - De `ListView` en de bijbehorende widgets worden aangepast om een visueel correcte en gebalanceerde weergave te garanderen.

    2.  **Favorieten per Gebruiker:**
        - **Datamodel Aanpassen:** Het `DailyEntry` model wordt aangepast. Het veld `isFavorite` (een boolean) wordt vervangen door `favoritedBy` (een lijst van gebruiker-UIDs).
        - **Provider Aanpassen:** De `toggleFavorite` methode in de `ProfileProvider` wordt bijgewerkt. In plaats van een boolean te wisselen, voegt het nu de UID van de huidige gebruiker toe aan of verwijdert het uit de `favoritedBy` lijst in Firestore.
        - **UI Aanpassen (`CalendarScreen` & `FavoritesScreen`):**
            - De logica wordt aangepast om te controleren of de UID van de *huidige* gebruiker in de `favoritedBy` lijst staat.
            - Dit zorgt ervoor dat de favorieten-status (het ster-icoon) correct wordt weergegeven voor elke individuele gebruiker.
            - Het `FavoritesScreen` zal alleen de foto's tonen die door de *huidige* gebruiker als favoriet zijn gemarkeerd.
