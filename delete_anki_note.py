import json
import urllib.request
import sys

# --- Fonctions de communication avec AnkiConnect ---
def request(action, **params):
    return {'action': action, 'params': params, 'version': 6}

def invoke(action, **params):
    requestJson = json.dumps(request(action, **params)).encode('utf-8')
    try:
        response = json.load(urllib.request.urlopen(urllib.request.Request('http://localhost:8765', requestJson)))
    except urllib.error.URLError:
        print(f"❌ Impossible de se connecter à Anki.")
        print(f"👉 Assurez-vous qu'Anki est ouvert et que l'add-on AnkiConnect est installé.")
        sys.exit(1)

    if len(response) != 2:
        raise Exception('La réponse a un nombre de champs inattendu.')
    if 'error' not in response:
        raise Exception('Champ erreur manquant dans la réponse.')
    if response['error'] is not None:
        raise Exception(response['error'])
    return response['result']

# --- Logique principale ---
def main():
    print("--- Suppression de note Anki par ID ---")
    try:
        # 1. Demande de l'ID
        raw_input = input("Entrez l'ID de la note (ex: 1698...): ")
        
        # 2. Nettoyage (retrait des espaces)
        clean_input = raw_input.replace(" ", "").strip()
        
        # Vérification numérique
        if not clean_input.isdigit():
            print("❌ Erreur : L'ID doit contenir uniquement des chiffres.")
            return

        note_id = int(clean_input)

        # 3. Vérification d'existence (notesInfo)
        info = invoke('notesInfo', notes=[note_id])
        
        # Si la liste est vide ou si le premier élément est vide/null
        if not info or not info[0]:
            print(f"⚠️ La note avec l'ID {note_id} n'existe pas (ou a déjà été supprimée).")
            return

        # 4. Suppression
        invoke('deleteNotes', notes=[note_id])
        print(f"✅ Succès : La note {note_id} a été supprimée.")

    except Exception as e:
        print(f"❌ Une erreur interne est survenue : {e}")

if __name__ == "__main__":
    main()
