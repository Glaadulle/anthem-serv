"""Partie de hub partagé d'un chef d'escouade : Blaze lui donne l'identifiant HUB_GAME_ID_BASE + persona du chef (crates/blaze, open_shared_hubs). Son ClientJoinMultiplayer devient un StartServer en hôte pair (peer_launch.s) qui recharge le hub ; gdb_active_mission.gdb ne doit pas le prendre pour un lancement de mission."""

HUB_GAME_ID_BASE = 1_000_000_000


def is_hub_game(game_id):
    return game_id >= HUB_GAME_ID_BASE
