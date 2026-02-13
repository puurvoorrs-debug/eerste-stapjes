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
-   **Status:** Voltooid.
-   **Probleem:** De `flutter build apk --release` commando faalde door een type-fout. Een `Map<dynamic, dynamic>` werd doorgegeven waar een `Map<DateTime, DailyEntry>` verwacht werd.
-   **Oplossing:** Het type is expliciet gecast naar `Map<DateTime, DailyEntry>` bij het doorgeven van de data, wat de build-fout heeft opgelost.

---

## Huidige Taak: Swipe-navigatie op Kalenderscherm

### Doel

De gebruiker in staat stellen om direct op het kalenderscherm door de dagen met foto's te navigeren door te swipen over het contentgedeelte (foto en beschrijving).

### Plan van Aanpak

1.  **Implementeer `GestureDetector`:**
    *   Pas `lib/screens/calendar_screen.dart` aan.
    *   Wikkel de `Column` die de foto (`GestureDetector` met `Stack`) en de beschrijving (`Padding` met `Container`) bevat in een nieuwe `GestureDetector`.
    *   Implementeer de `onHorizontalDragEnd`-callback om veegbewegingen te detecteren.

2.  **Voeg Swipe-logica toe:**
    *   Creëer een nieuwe methode, bijvoorbeeld `_handleSwipe(DragEndDetails details)`.
    *   **Bepaal swipe-richting:** Analyseer de `primaryVelocity` van de `DragEndDetails`. Een positieve snelheid betekent een swipe naar rechts (vorige dag), een negatieve snelheid betekent een swipe naar links (volgende dag).
    *   **Vind volgende/vorige dag:**
        *   Haal de gesorteerde lijst met datums op waarvoor een `entry` bestaat (`_entries.keys.toList()..sort()`).
        *   Vind de huidige index van `_selectedDay` in deze lijst.
        *   Bereken de nieuwe index door 1 op te tellen (links swipen) of af te trekken (rechts swipen).
        *   Zorg ervoor dat de index binnen de grenzen van de lijst blijft.
    *   **Update de state:** Roep `setState` aan om `_selectedDay` en `_focusedDay` bij te werken met de nieuwe datum uit de lijst. Dit zal de UI vernieuwen en de content van de nieuwe dag tonen.

3.  **Testen:**
    *   Verifieer dat swipen naar links en rechts op het contentgedeelte van het kalenderscherm correct navigeert naar de volgende en vorige dag met een foto.
    *   Controleer of de kalenderweergave zichzelf ook correct bijwerkt en de nieuwe geselecteerde dag markeert.
    *   Test de randgevallen: wat gebeurt er als je op de eerste of laatste dag in de lijst swipet?
