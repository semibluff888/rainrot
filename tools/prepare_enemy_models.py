"""Prepare the two official Sketchfab GLBs; preserves geometry, rigs and source animation.

Input archives stay in .runtime/monster_sources. No network or account data is used.
Generates editor-readable glTF, 2K/1K texture tiers and source attribution hashes.
"""
import copy
import hashlib
import io
import json
import struct
from pathlib import Path
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
MODELS = {
    "smily": ("Smily horror monster", "Bento", "https://sketchfab.com/3d-models/smily-horror-monster-3d3fc31eddaa409a8f2df564823154e1"),
    "nurse": ("Horror Mutant Bloody Nurse Gore (RIGGED)", "KrimzonHaze", "https://sketchfab.com/3d-models/horror-mutant-bloody-nurse-gore-rigged-2bc6e1cac98e458a824691009ef2433c"),
}


def load_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2 and length == len(data), path
    offset, document, binary = 12, None, None
    while offset < length:
        size, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset+8:offset+8+size]
        if kind == 0x4E4F534A:
            document = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + size
    assert document and binary and document.get("skins"), "Missing geometry/rig in " + str(path)
    return document, binary


def prepare(role, source):
    document, binary = load_glb(source)
    assert "KHR_draco_mesh_compression" not in document.get("extensionsRequired", [])
    dest = ROOT / "assets" / "models" / "enemies" / role
    dest.mkdir(parents=True, exist_ok=True)
    for tier in ("high", "low"):
        (dest / "textures" / tier).mkdir(parents=True, exist_ok=True)
    base_images = set()
    for material in document.get("materials", []):
        ref = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if ref:
            base_images.add(document["textures"][ref["index"]]["source"])
    images_report = []
    for i, entry in enumerate(document.get("images", [])):
        view = document["bufferViews"][entry["bufferView"]]
        offset = view.get("byteOffset", 0)
        img = Image.open(io.BytesIO(binary[offset:offset + view["byteLength"]])).convert("RGBA")
        original_size = img.size
        if i in base_images:
            alpha = img.getchannel("A")
            # Keep the selected asset recognizable; take the edge off saturated reds.
            img = ImageEnhance.Color(img.convert("RGB")).enhance(.86).convert("RGBA")
            img.putalpha(alpha)
        for tier, limit in (("high", 2048), ("low", 1024)):
            output = img.copy()
            output.thumbnail((limit, limit), Image.Resampling.LANCZOS)
            output.save(dest / "textures" / tier / f"image_{i:02d}.png", optimize=True)
        entry.clear()
        entry["uri"] = f"textures/high/image_{i:02d}.png"
        images_report.append({"image": i, "original_size": original_size, "base_color": i in base_images})
    # Only retain binary ranges still referenced by vertex/index/animation data.
    used_end = max((v.get("byteOffset", 0) + v["byteLength"] for j, v in enumerate(document["bufferViews"])
                    if any(a.get("bufferView") == j for a in document.get("accessors", []))), default=len(binary))
    # Image buffer views remain valid even though images now have external URIs.
    # Retain the original buffer, avoiding any changes to rig/accessor offsets.
    (dest / "model.bin").write_bytes(binary)
    document["buffers"] = [{"uri": "model.bin", "byteLength": len(binary)}]
    (dest / "model.gltf").write_text(json.dumps(document, ensure_ascii=False, indent=2), encoding="utf-8")
    title, author, url = MODELS[role]
    provenance = {"id": role, "title": title, "author": author, "source": url,
                  "download": "Official Sketchfab 2K GLB, downloaded through signed-in website",
                  "license": "CC-BY-4.0", "license_url": "https://creativecommons.org/licenses/by/4.0/",
                  "date": "2026-09-07", "sha256_source_glb": hashlib.sha256(source.read_bytes()).hexdigest(),
                  "sha256_source_archive": hashlib.sha256(source.with_suffix(".zip").read_bytes()).hexdigest(),
                  "changes": "Externalized glTF textures; 2K/1K tiers; base-color saturation 86%; game animation/material/scale adaptation.",
                  "skins": len(document["skins"]), "animations": [a.get("name", "") for a in document.get("animations", [])],
                  "images": images_report}
    (dest / "SOURCE.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2), encoding="utf-8")
    (dest / "LICENSE.txt").write_text(f"{title}\nAuthor: {author}\n{url}\n\nCreative Commons Attribution 4.0 International (CC BY 4.0)\nhttps://creativecommons.org/licenses/by/4.0/\n\nModified for RAINROT: see SOURCE.json. No endorsement by the original author is implied.\n", encoding="utf-8")
    print(role, "nodes", len(document["nodes"]), "skins", len(document["skins"]), "animations", provenance["animations"])
    for skin in document["skins"]:
        print("BONES", [(j, document["nodes"][j].get("name")) for j in skin["joints"]])


if __name__ == "__main__":
    for role in MODELS:
        source = ROOT / ".runtime" / "monster_sources" / f"{role}.glb"
        if not source.exists(): source = ROOT / "source_archives" / f"{role}.glb"
        prepare(role, source)
