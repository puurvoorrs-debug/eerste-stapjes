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
-   **Profiel Volgen:** Gebruikers kunnen andere profielen volgen via een unieke code. Er is een controle ingebouwd die vereist dat een gebruiker eerst zelf een volledige naam en profielfoto heeft ingesteld alvorens anderen te kunnen volgen.

### Sociale Interactie

-   **Likes:** Zowel eigenaren als volgers kunnen posts 'liken'.
-   **Reacties:** Gebruikers kunnen reageren op posts en hun eigen reacties bewerken of verwijderen.
-   **Favorieten:** Gebruikers kunnen posts markeren als persoonlijk favoriet.
-   **Volgerslijst:** Eigenaren kunnen zien wie hun profielen volgt.

### Notificaties

-   **Real-time Notificaties:** Gebruikers ontvangen pushnotificaties voor belangrijke gebeurtenissen zoals nieuwe volgers, likes en reacties.
-   **Specifieke Notificaties:**
    -   Nieuwe volger: De eigenaar van een profiel ontvangt een notificatie.
    -   Nieuwe like: De eigenaar van de post ontvangt een notificatie.
    -   Nieuwe reactie: De eigenaar van de post ontvangt een notificatie.

### UI/UX & Theming

-   **Merkconsistentie op Inlogscherm:**
    -   De huisstijl is doorgevoerd op het `login_screen.dart`.
    -   De titel "Eerste stapjes", de geanimeerde SVG-voetjes, en de "Inloggen met Google"-knop gebruiken nu consistent de primaire themakleur van de app voor een herkenbare en uniforme eerste indruk.
-   **Verfijnde Knopstyling op Profielselectie:**
    -   De knoppen op `profile_selection_screen.dart` zijn opnieuw ontworpen voor betere visuele hiërarchie en consistentie met het app-thema.
    -   De hoofdactie "Nieuw profiel aanmaken" (`ElevatedButton`) gebruikt nu de primaire themakleur als achtergrond.
    -   De secundaire actie "Een profiel volgen" (`OutlinedButton`) gebruikt de primaire themakleur voor de rand en tekst.
    -   De "Volgen"-knop in de pop-up is eveneens gestyled met de primaire themakleur, wat zorgt voor een naadloze gebruikerservaring.

### Probleemoplossing & Herstel

-   **Status:** Voltooid.
-   **Probleem:** De release-versie van de Android-app crashte bij het inloggen met Google, omdat de SHA-1 en SHA-256-fingerprints van de release-keystore niet waren toegevoegd aan het Firebase-project.
-   **Oplossing:** Er is een nieuwe `upload-keystore.jks` gegenereerd en de build-configuratie is aangepast. De correcte SHA-fingerprints zijn toegevoegd aan Firebase, waarna de app opnieuw is gebouwd.
