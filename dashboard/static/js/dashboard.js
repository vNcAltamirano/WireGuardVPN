"use strict";

const REFRESH_MS = 5000;

function humanBytes(bytes) {
    const units = ["B", "KB", "MB", "GB", "TB"];

    let value = Number(bytes || 0);

    for (const unit of units) {
        if (value < 1024 || unit === units[units.length - 1]) {
            if (unit === "B") {
                return `${Math.round(value)} ${unit}`;
            }

            return `${value.toFixed(1)} ${unit}`;
        }

        value /= 1024;
    }

    return `${bytes} B`;
}

function relativeHandshake(timestamp) {
    timestamp = Number(timestamp || 0);

    if (!timestamp) {
        return "nunca";
    }

    const now = Math.floor(Date.now() / 1000);
    const delta = Math.max(0, now - timestamp);

    if (delta < 60) {
        return `hace ${delta} s`;
    }

    if (delta < 3600) {
        return `hace ${Math.floor(delta / 60)} min`;
    }

    if (delta < 86400) {
        return `hace ${Math.floor(delta / 3600)} h`;
    }

    return `hace ${Math.floor(delta / 86400)} d`;
}

async function refreshPeers() {
    try {
        const response = await fetch("/api/peers", {
            cache: "no-store",
        });

        if (!response.ok) {
            return;
        }

        const peers = await response.json();

        let active = 0;
        let online = 0;
        let revoked = 0;

        for (const peer of peers) {
            if (peer.status === "active") {
                active++;

                if (peer.online) {
                    online++;
                }
            }

            if (peer.status === "revoked") {
                revoked++;
            }

            const row = document.querySelector(
                `[data-peer="${CSS.escape(peer.name)}"]`
            );

            if (!row) {
                continue;
            }

            const state = row.querySelector("[data-field='state']");
            const handshake = row.querySelector(
                "[data-field='handshake']"
            );
            const rx = row.querySelector("[data-field='rx']");
            const tx = row.querySelector("[data-field='tx']");
            const endpoint = row.querySelector(
                "[data-field='endpoint']"
            );

            if (state) {
                state.textContent = peer.online
                    ? "● ONLINE"
                    : "● OFFLINE";

                state.className = peer.online
                    ? "online"
                    : "offline";
            }

            if (handshake) {
                handshake.textContent =
                    relativeHandshake(peer.latest_handshake);
            }

            if (rx) {
                rx.textContent = humanBytes(peer.rx);
            }

            if (tx) {
                tx.textContent = humanBytes(peer.tx);
            }

            if (endpoint) {
                endpoint.textContent =
                    peer.endpoint && peer.endpoint !== "(none)"
                        ? peer.endpoint
                        : "-";
            }
        }

        const activeNode = document.querySelector(
            "[data-stat='active']"
        );
        const onlineNode = document.querySelector(
            "[data-stat='online']"
        );
        const revokedNode = document.querySelector(
            "[data-stat='revoked']"
        );

        if (activeNode) activeNode.textContent = active;
        if (onlineNode) onlineNode.textContent = online;
        if (revokedNode) revokedNode.textContent = revoked;

    } catch (error) {
        console.debug("Peer refresh failed", error);
    }
}

function openQr(peerName) {
    const dialog = document.getElementById("qr-dialog");
    const image = document.getElementById("qr-image");
    const title = document.getElementById("qr-peer-name");

    if (!dialog || !image) {
        return;
    }

    title.textContent = peerName;

    image.src =
        `/admin/peers/${encodeURIComponent(peerName)}/qr` +
        `?ts=${Date.now()}`;

    dialog.showModal();
}

function closeQr() {
    document.getElementById("qr-dialog")?.close();
}

function openCreatePeer() {
    document.getElementById("create-peer-dialog")?.showModal();
}

function closeCreatePeer() {
    document.getElementById("create-peer-dialog")?.close();
}

window.openQr = openQr;
window.closeQr = closeQr;
window.openCreatePeer = openCreatePeer;
window.closeCreatePeer = closeCreatePeer;

window.addEventListener("DOMContentLoaded", () => {
    refreshPeers();

    setInterval(
        refreshPeers,
        REFRESH_MS
    );
});
