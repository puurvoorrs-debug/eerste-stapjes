
# App Blueprint: Eerste Stapjes

## Overzicht

Eerste Stapjes is een mobiele applicatie gebouwd met Flutter, ontworpen om de groei en ontwikkeling van kinderen vast te leggen en te bewaren. Gebruikers kunnen inloggen met hun Google-account en vervolgens individuele profielen aanmaken voor hun kinderen. Voor elk profiel kan de gebruiker een visuele tijdlijn creëren door dagelijks een foto toe te voegen. De app maakt intensief gebruik van Firebase voor backend-services, waaronder authenticatie, dataopslag en bestandsopslag.

---

## Geïmplementeerde Features, Stijl & Design

### Architectuur & Technologie

-   **Framework:** Flutter
-   **Backend:** Firebase (Authentication, Firestore, Storage)
-   **State Management:** Provider
-   **Authenticatie:** Google Sign-In.
-   **Opslag:** Firebase Storage voor media, Firestore voor metadata.

### Kernfunctionaliteit

-   **Gebruikersprofielen:** Aanmaken, bijwerken en verwijderen van kinderprofielen.
-   **Fotogalerij:** Grid-weergave van alle geüploade foto's voor een profiel.
-   **Dagelijkse Foto Upload:** Gebruikers kunnen een foto en beschrijving toevoegen als dagelijkse 'entry'. De app zorgt ervoor dat er maar één entry per dag mogelijk is door een oude entry automatisch te verwijderen bij het posten van een nieuwe op dezelfde dag.

### Sociale Interactie:
    - **Dagelijkse Momenten (Entries):** Eigenaren kunnen dagelijks een foto met beschrijving toevoegen.
    - **Likes:** Zowel eigenaren als volgers kunnen posts 'liken'.
    - **Reacties:** Gebruikers kunnen reageren op posts.
    - **Favorieten:** Gebruikers kunnen posts markeren als persoonlijk favoriet.
    - **Volgerslijst:** Eigenaren kunnen zien wie hun profielen volgt.

### User Interface (UI) & User Experience (UX)

-   **Design Stijl:** Material Design 3.
-   **Thema:** Ondersteuning voor lichte en donkere modus.
-   **Layout:** Diverse layout-problemen zijn opgelost voor een strakkere en professionelere uitstraling.

---

## Volgende Stap: Notificaties

- **Doel:** Het implementeren van push notificaties om gebruikers te informeren over interacties zoals nieuwe volgers, likes en reacties.

---

## Huidig Plan: Beheerfunctionaliteit voor Reacties en Posts

-   **Status:** Implementatie.
-   **Doel:** Gebruikers meer controle geven over hun eigen content door bewerk- en verwijderopties toe te voegen voor reacties en posts.

### Fase 1: Reactiebeheer (Bewerken & Verwijderen)

-   **UI-elementen:**
    -   Een `bottomSheet` wordt getoond bij het lang indrukken van een eigen reactie.
    -   Opties in het menu: "Bewerken" en "Verwijderen".
-   **Logica:**
    -   **Bewerken:** Toont een `AlertDialog` met de huidige reactietekst, die de gebruiker kan aanpassen en opslaan.
    -   **Verwijderen:** Toont een bevestigingsdialoog voordat de reactie definitief uit Firestore wordt verwijderd.

### Fase 2: Postbeheer (Verwijderen)

-   **UI-elementen:**
    -   Een `PopupMenuButton` (drie puntjes) wordt toegevoegd aan elke post in de `PhotoGrid`.
    -   De optie "Verwijderen" wordt alleen getoond als de ingelogde gebruiker de eigenaar van de post is.
-   **Logica:**
    -   Bij selectie wordt de `deleteDailyEntry` functie aangeroepen.
    -   Deze functie verwijdert zowel de foto uit Firebase Storage als het bijbehorende document uit Firestore.

### Implementatiedetails

1.  **Logica aanpassen in `ProfileProvider`:**
    -   De bestaande `addPhotoToProfile` functie wordt aangepast.
    -   Voordat een nieuwe foto wordt geüpload, controleert de functie of er al een `daily_entry` bestaat voor die specifieke dag.
    -   Indien ja, wordt de nieuwe `deleteDailyEntry` functie aangeroepen om de oude post volledig op te ruimen voordat de nieuwe wordt aangemaakt. Dit garandeert de "schone lei" die is gevraagd.
