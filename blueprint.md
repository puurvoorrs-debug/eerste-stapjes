# App Blueprint: Eerste Stapjes

## Overzicht

Eerste Stapjes is een mobiele applicatie gebouwd met Flutter, ontworpen om de groei en ontwikkeling van kinderen vast te leggen en te bewaren. Gebruikers kunnen inloggen met hun Google-account en vervolgens individuele profielen aanmaken voor hun kinderen. Voor elk profiel kan de gebruiker een visuele tijdlijn creëren door dagelijks een foto toe te voegen. De app maakt intensief gebruik van Firebase voor backend-services, waaronder authenticatie, dataopslag en bestandsopslag.

---

## Geïmplementeerde Features, Stijl & Design

### Architectuur & Technologie

- **Framework:** Flutter
- **Backend:** Firebase
  - **Authenticatie:** Firebase Auth (geïntegreerd met Google Sign-In).
  - **Database:** Cloud Firestore voor het opslaan van profielgegevens, dagelijkse entries en metadata van de dagelijkse foto's.
  - **Opslag:** Firebase Storage voor het hosten van profielfoto's en de dagelijkse foto-uploads.
- **State Management:** `provider` package wordt gebruikt voor het beheren van de app-status.
- **Navigatie:** Standaard Flutter `MaterialPageRoute` navigatie.

### Kernfunctionaliteiten

1.  **Gebruikersauthenticatie:**
    - Veilige login via Google Sign-In.

2.  **Profielbeheer & Rollen:**
    - **Ouder/Verzorger (Eigenaar):** Kan profielen aanmaken, bewerken, verwijderen en delen via een unieke code.
    - **Volger:** Kan een profiel volgen met de unieke code en heeft alleen-lezen toegang.

3.  **Dagelijkse Momenten (Entries):**
    - Eigenaren kunnen dagelijks een foto toevoegen aan een profiel.
    - **Persoonlijke Favorieten:** Zowel eigenaren als volgers kunnen foto's als 'favoriet' markeren. Deze favorieten zijn per gebruiker opgeslagen.

### User Interface (UI) & User Experience (UX)

- **Design Stijl:** Material Design 3.
- **Thema:** Ondersteuning voor lichte en donkere modus.
- **Layout:** Diverse layout-problemen zijn opgelost voor een strakkere en professionelere uitstraling.

---

## Huidig Plan: Transformatie naar een Sociaal Platform

- **Status:** Grote Feature-uitbreiding.
- **Doel:** De applicatie transformeren van een persoonlijk dagboek naar een interactief sociaal platform voor families, met meer personalisatie en interactiemogelijkheden.

### Fase 1: Uitbreiding van de Data Structuur

1.  **`UserModel` introduceren:**
    -   Een nieuwe root-collectie `users` in Firestore.
    -   Elk document wordt een gebruikersprofiel, met velden als `uid`, `displayName`, en `photoUrl`.

2.  **`DailyEntry` model aanpassen:**
    -   Toevoegen van een `description` veld (String) voor de foto-omschrijving.
    -   Toevoegen van een `likes` veld (List van `uid`'s) voor de openbare like-functionaliteit.

3.  **`CommentModel` creëren:**
    -   Voor elke `DailyEntry` wordt een subcollectie `comments` aangemaakt.
    -   Elk document in deze subcollectie is een `CommentModel` met velden als `commentText`, `userId`, `userName`, `userPhotoUrl`, en `timestamp`.

### Fase 2: Implementatie van Gebruikersaccounts

1.  **Account Setup Scherm:**
    -   Een nieuw scherm waar gebruikers na hun eerste login hun publieke `displayName` en `photoUrl` kunnen instellen.

### Fase 3: Sociale Features op het Kalenderscherm

1.  **Beschrijvingen:**
    -   Tijdens het uploaden van een foto kan de eigenaar een beschrijving toevoegen.
    -   De beschrijving wordt prominent onder de foto weergegeven.

2.  **Like-functionaliteit:**
    -   Een hart-icoon wordt toegevoegd onder elke foto.
    -   Gebruikers kunnen een foto 'liken'. Het totale aantal likes wordt naast het icoon weergegeven.

3.  **Reactiesysteem (Comment Section):**
    -   Onder de foto en beschrijving komt een volledige commentaarsectie.
    -   Een invoerveld om een nieuwe reactie te plaatsen.
    -   Een lijst van alle bestaande reacties, waarbij de profielfoto en naam van de reageerder zichtbaar zijn.

### Fase 4: Inzicht in Volgers

1.  **Volgerslijst Scherm:**
    -   Een nieuw scherm, alleen toegankelijk voor de eigenaar, dat een lijst toont van alle gebruikers die het profiel volgen.
    -   Deze lijst toont de `displayName` en `photoUrl` van elke volger.

### Fase 5: Accountinstellingen (NIEUW)

1.  **Toegangspunt creëren:**
    -   Een "Instellingen" icoon wordt toegevoegd aan de `AppBar` van het `ProfileSelectionScreen`.
    -   Dit icoon navigeert de gebruiker naar het `AccountSettingsScreen`.
2.  **`AccountSettingsScreen` bouwen:**
    -   Een nieuw scherm waar de gebruiker zijn huidige `displayName` en `photoUrl` kan bekijken en bewerken.
    -   Functionaliteit voor het kiezen en uploaden van een nieuwe profielfoto.
    -   Een tekstveld om de `displayName` te wijzigen.
3.  **Logica voor opslaan:**
    -   Een opslagfunctie die de bijgewerkte gegevens wegschrijft naar het document van de gebruiker in de `users` collectie in Firestore.
