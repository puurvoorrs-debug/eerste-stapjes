# App Blueprint: Eerste Stapjes

## Overzicht

Eerste Stapjes is een mobiele applicatie gebouwd met Flutter, ontworpen om de groei en ontwikkeling van kinderen vast te leggen en te bewaren. Gebruikers kunnen inloggen met hun Google-account en vervolgens individuele profielen aanmaken voor hun kinderen. Voor elk profiel kan de gebruiker een visuele tijdlijn creëren door dagelijks een foto toe te voegen. De app maakt intensief gebruik van Firebase voor backend-services, waaronder authenticatie, dataopslag en bestandsopslag.

---

## Geïmplementeerde Features, Stijl & Design

### Architectuur & Technologie

-   **Framework:** Flutter
-   **Backend:** Firebase (Authentication, Firestore, Storage, Cloud Functions)
-   **State Management:** Provider
-   **Authenticatie:** Google Sign-In.
-   **Opslag:** Firebase Storage voor media, Firestore voor metadata.

### Kernfunctionaliteit

-   **Gebruikersprofielen:** Aanmaken, bijwerken en verwijderen van kinderprofielen.
-   **Fotogalerij:** Grid-weergave van alle geüploade foto's voor een profiel.
-   **Dagelijkse Foto Upload:** Gebruikers kunnen een foto en beschrijving toevoegen als dagelijkse 'entry'. De app zorgt ervoor dat er maar één entry per dag mogelijk is.
-   **Post Beheer:** Gebruikers kunnen hun eigen posts verwijderen.

### Sociale Interactie:
    - **Likes:** Zowel eigenaren als volgers kunnen posts 'liken'.
    - **Reacties:** Gebruikers kunnen reageren op posts en hun eigen reacties bewerken of verwijderen.
    - **Favorieten:** Gebruikers kunnen posts markeren als persoonlijk favoriet.
    - **Volgerslijst:** Eigenaren kunnen zien wie hun profielen volgt.

### Notificaties & Achtergrondtaken
-   **Push Notificaties (Cloud Functions):** Firebase Cloud Functions worden gebruikt om pushnotificaties te versturen voor:
    - Nieuwe volgers.
    - Nieuwe foto's geplaatst door gevolgde profielen.
    - Likes en reacties op eigen foto's.
-   **Dagelijkse Herinnering (Cloud Functions):** Een dagelijkse, geplande Cloud Functie controleert of er een foto is geplaatst en stuurt een herinnering indien nodig.

### User Interface (UI) & User Experience (UX)

-   **Design Stijl:** Material Design 3.
-   **Thema:** Ondersteuning voor lichte en donkere modus.
-   **Layout:** Diverse layout-problemen zijn opgelost voor een strakkere en professionelere uitstraling.

---

## Recent Bugfixes: Uploads & Notificaties

-   **Status:** Voltooid.
-   **Probleem:** Na een eerdere wijziging was het uploaden van foto's gebroken. Een poging dit te herstellen, zorgde er vervolgens voor dat de notificaties voor likes en reacties niet meer werkten, omdat de app-code en de Cloud Functies niet meer op één lijn zaten qua datastructuur (`profiles` vs `users` collectie).
-   **Oplossing:**
    1.  **Herstel App-code:** De Flutter-applicatiecode is volledig teruggezet naar een vorige, stabiele staat, waardoor het uploadprobleem direct werd verholpen.
    2.  **Correctie Cloud Functies:** In plaats van de app opnieuw aan te passen, zijn de Cloud Functies in `functions/index.js` volledig herschreven.
        *   Alle database-triggers luisteren nu naar de correcte `profiles` collectie.
        *   De logica voor het afhandelen van nieuwe likes, reacties en het versturen van notificaties naar volgers is volledig afgestemd op de datastructuur die de app gebruikt.
    3.  **Linting & Deployment:** De Cloud Functies zijn gelint, gecorrigeerd en succesvol opnieuw gedeployed, waardoor de backend nu synchroon loopt met de frontend.
-   **Resultaat:** Zowel de foto-uploadfunctionaliteit als het notificatiesysteem voor sociale interacties (likes, comments) werken nu correct en betrouwbaar.
