# craftos-mcp — embedded CraftOS-PC + Rust (rmcp) MCP server.
# Builds the whole emulator as a static lib, links it into the Rust server, and
# serves streamable-HTTP (/mcp) and legacy SSE (/sse + /message) concurrently.
FROM rust:1-bookworm

# Emulator C/C++ deps (Ubuntu/Debian build path from the CraftOS-PC README) +
# the headers darwin/linux platform code pulls in.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git build-essential pkg-config ca-certificates \
      libsdl2-dev libpoco-dev libssl-dev libpng-dev libpng++-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# The emulator + MCP server source lives in the craftos2 fork; the ROM is
# licensed separately and cloned at build time.
# Pin to a commit (not a branch): reproducible, and changing it busts Docker's
# layer cache so a rebuild actually picks up new emulator/server code.
ARG CRAFTOS_REPO=https://github.com/r33drichards/craftos2
ARG CRAFTOS_REF=c14db4b
RUN git clone --recurse-submodules "$CRAFTOS_REPO" craftos2 \
 && git -C craftos2 checkout "$CRAFTOS_REF" \
 && git -C craftos2 submodule update --init --recursive \
 && git clone --depth 1 https://github.com/MCJack123/craftos2-rom craftos2-rom

WORKDIR /app/craftos2

# 1) Lua, 2) configure headless-only, 3) compile emulator objects and archive
# everything except main() into libcraftos2.a (the final binary link is expected
# to fail — we only need the objects), 4) build the Rust server.
RUN make -C craftos2-lua linux \
 && ./configure --without-png --without-webp --without-ncurses --without-sdl_mixer --with-txt \
 && (make -j"$(nproc)" || true) \
 && test -f obj/Computer.o \
 && ar rcs embed/libcraftos2.a $(ls obj/*.o | grep -v '/main\.o$')
RUN cd mcp && cargo build --release

# Headless: dummy SDL drivers, ROM path, both endpoints on $PORT (Railway sets it).
ENV CRAFTOS_ROM=/app/craftos2-rom \
    CRAFTOS_SIM_DIR=/app/craftos2/sim \
    SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy \
    PORT=8080
EXPOSE 8080
CMD ["./mcp/target/release/craftos-mcp", "--transport", "all"]
