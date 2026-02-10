# App Blueprint: Eerste Stapjes

## Overzicht

Eerste Stapjes is een mobiele applicatie gebouwd met Flutter, ontworpen om de groei en ontwikkeling van kinderen vast te leggen en te bewaren. Gebruikers kunnen inloggen met hun Google-account en vervolgens individuele profielen aanmaken voor hun kinderen. Voor elk profiel kan de gebruiker een visuele tijdlijn creëren door dagelijks een foto toe te voegen. De app maakt intensief gebruik van Firebase voor backend-services, waaronder authenticatie, dataopslag en bestandsopslag.

---

## Geïmplementeerde Features, Stijl & Design

### Architectuur & Technologie

- **Framework:** Flutter
- **Backend:** Firebase
  - **Authenticatie:** Firebase Auth (geïntegreerd met Google Sign-In).
  - **Database:** Cloud Firestore voor het opslaan van profielgegevens, dagelijkse entries en metadata.
  - **Opslag:** Firebase Storage voor het hosten van profielfoto's en dagelijkse uploads.
- **State Management:** `provider` package.
- **Navigatie:** Standaard Flutter `MaterialPageRoute` navigatie.

### Kernfunctionaliteiten

1.  **Gebruikersauthenticatie & Accounts:**
    - Veilige login via Google Sign-In.
    - Gebruikers kunnen een accountnaam en profielfoto instellen en deze later wijzigen.

2.  **Profielbeheer & Rollen:**
    - **Ouder/Verzorger (Eigenaar):** Kan kinderprofielen aanmaken, bewerken, verwijderen en delen via een unieke code.
    - **Volger:** Kan een profiel volgen met de code en krijgt lees-toegang.

3.  **Sociale Interactie:**
    - **Dagelijkse Momenten (Entries):** Eigenaren kunnen dagelijks een foto met beschrijving toevoegen.
    - **Likes:** Zowel eigenaren als volgers kunnen posts 'liken'.
    - **Reacties:** Gebruikers kunnen reageren op posts.
    - **Favorieten:** Gebruikers kunnen posts markeren als persoonlijk favoriet.
    - **Volgerslijst:** Eigenaren kunnen zien wie hun profielen volgt.

### User Interface (UI) & User Experience (UX)

- **Design Stijl:** Material Design 3.
- **Thema:** Ondersteuning voor lichte en donkere modus.
- **Layout:** Diverse layout-problemen zijn opgelost voor een strakkere en professionelere uitstraling.

---

## Huidig Plan: Beheerfunctionaliteit voor Reacties en Posts

- **Status:** Implementatie.
- **Doel:** Gebruikers meer controle geven over hun eigen content door bewerk- en verwijderopties toe te voegen voor reacties en posts.

### Fase 1: Reactiebeheer (Bewerken & Verwijderen)

1.  **UI Aanpassingen (`photo_detail_screen.dart`):**
    -   Bij elke reactie wordt een contextmenu (icoon met drie puntjes) toegevoegd.
    -   Dit menu is **alleen zichtbaar** als de ingelogde gebruiker de auteur van de reactie is.
    -   Het menu bevat de opties "Bewerken" en "Verwijderen".
2.  **Logica in `ProfileProvider`:**
    -   `deleteComment(profileId, entryDate, commentId)`: Implementeren van een functie die het specifieke commentaar-document uit de subcollectie in Firestore verwijdert.
    -   `updateComment(profileId, entryDate, commentId, newText)`: Implementeren van een functie die de tekst van een bestaand commentaar bijwerkt.
3.  **Dialogen voor Interactie:**
    -   Een `AlertDialog` tonen om de gebruiker te vragen de verwijdering te bevestigen.
    -   Een dialoog met een `TextField` tonen waarin de gebruiker zijn reactie kan bewerken.

### Fase 2: Posts Verwijderen

1.  **UI Aanpassing (`photo_detail_screen.dart`):**
    -   Een prullenbak-icoon wordt toegevoegd aan de `AppBar` van het detailscherm.
    -   Dit icoon is **alleen zichtbaar** als de ingelogde gebruiker de eigenaar van het profiel is.
2.  **Logica in `ProfileProvider`:**
    -   `deleteDailyEntry(profileId, entryDate)`: Creëren van een robuuste functie die de volgende stappen uitvoert:
        1.  **Subcollecties verwijderen:** Alle documenten in de `comments` subcollectie van de `daily_entry` worden verwijderd.
        2.  **Foto verwijderen:** De bijbehorende foto wordt uit Firebase Storage verwijderd met `refFromURL().delete()`.
        3.  **Hoofddocument verwijderen:** Het `daily_entry` document zelf wordt verwijderd, waarmee de beschrijving, likes, en favorieten-lijsten ook verdwijnen.

### Fase 3: Schone Lei bij Nieuwe Upload

1.  **Logica aanpassen in `ProfileProvider`:**
    -   De bestaande `addPhotoToProfile` functie wordt aangepast.
    -   Voordat een nieuwe foto wordt geüpload, controleert de functie of er al een `daily_entry` bestaat voor die specifieke dag.
    -   Indien ja, wordt de nieuwe `deleteDailyEntry` functie aangeroepen om de oude post volledig op te ruimen voordat de nieuwe wordt aangemaakt. Dit garandeert de "schone lei" die is gevraagd.
