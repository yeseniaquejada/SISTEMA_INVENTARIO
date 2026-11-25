/* Yesenia Quejada Rojas - Claude — 24/11/2026. Ícono y grupo de cada ingrediente para "¿Le quitamos algo?" (Vender y la carta digital).
   Se reconoce por el nombre del insumo (sin tildes ni lo que va entre paréntesis): "Pan de perro" → 🥖 en "Pan y base",
   "Ensalada (porción)" → 🥬 en "Verduras y frutas". Lo que no se reconoce sale con 🍽️ en "Otros".
   Para un insumo nuevo basta con agregar una fila aquí; el orden importa (la primera que coincide gana). */
(function () {
    const GRUPOS = ['Pan y base', 'Carnes', 'Quesos', 'Verduras y frutas', 'Toppings', 'Papas', 'Salsas', 'Otros'];
    const ICONO_GRUPO = { 'Pan y base': '🍞', 'Carnes': '🥩', 'Quesos': '🧀', 'Verduras y frutas': '🥬', 'Toppings': '✨', 'Papas': '🍟', 'Salsas': '🥫', 'Otros': '🍽️' };
    const TABLA = [   // [palabra del nombre (sin tildes), ícono, grupo]
        // Ripio antes que papa: "Papa ripio" es un topping, no la porción de papas.
        [/ripio/, '🍟', 'Toppings'],
        [/pan de perro|pan perro/, '🥖', 'Pan y base'], [/\bpan\b/, '🍞', 'Pan y base'], [/arepa/, '🫓', 'Pan y base'],
        [/tortilla/, '🌯', 'Pan y base'], [/patacon/, '🍌', 'Pan y base'],
        [/tocineta|bacon/, '🥓', 'Carnes'], [/chicharron/, '🥓', 'Carnes'], [/salchicha|chorizo|butifarra|\bkit\b/, '🌭', 'Carnes'],
        [/pollo|chuzo/, '🍗', 'Carnes'], [/desmechad|cerdo|pulled/, '🍖', 'Carnes'], [/carne|lomo|churrasco/, '🥩', 'Carnes'],
        [/queso|mozzarella|lonchita|filadelfia|cheddar/, '🧀', 'Quesos'], [/crema|leche/, '🥛', 'Quesos'],
        [/ensalada|lechuga|repollo/, '🥬', 'Verduras y frutas'], [/guacamole|aguacate/, '🥑', 'Verduras y frutas'],
        [/pico de gallo|tomate|hogao/, '🍅', 'Verduras y frutas'], [/cebolla/, '🧅', 'Verduras y frutas'], [/pepino|pepinillo/, '🥒', 'Verduras y frutas'],
        [/pina/, '🍍', 'Verduras y frutas'], [/maduro|platano/, '🍌', 'Verduras y frutas'], [/zanahoria/, '🥕', 'Verduras y frutas'],
        [/pimenton/, '🫑', 'Verduras y frutas'], [/jalapeno|aji\b|picante/, '🌶️', 'Verduras y frutas'], [/cilantro|perejil/, '🌿', 'Verduras y frutas'],
        [/\bajo\b/, '🧄', 'Verduras y frutas'], [/limon/, '🍋', 'Verduras y frutas'],
        [/huevo/, '🥚', 'Toppings'], [/maicito|maiz/, '🌽', 'Toppings'], [/nacho/, '🌮', 'Toppings'],
        [/papa/, '🍟', 'Papas'],
        [/salsa/, '🥫', 'Salsas']
    ];
    const limpiar = t => (t || '').replace(/\s*\(.*\)\s*$/, '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

    /** { icono, grupo } del ingrediente; null si no se reconoce. */
    function buscar(nombre) {
        const n = limpiar(nombre), x = TABLA.find(([re]) => re.test(n));
        return x ? { icono: x[1], grupo: x[2] } : null;
    }
    /** Siempre devuelve algo: lo que no se reconoce va con 🍽️ en "Otros". */
    const de = nombre => buscar(nombre) || { icono: ICONO_GRUPO.Otros, grupo: 'Otros' };

    /** Agrupa la lista (objetos con .nombre) en el orden de GRUPOS y por nombre dentro de cada grupo: [{ grupo, icono, items }]. */
    function agrupar(lista) {
        const mapa = new Map();
        lista.forEach(i => { const g = de(i.nombre).grupo; (mapa.get(g) || mapa.set(g, []).get(g)).push(i); });
        return GRUPOS.filter(g => mapa.has(g)).map(g => ({
            grupo: g, icono: ICONO_GRUPO[g],
            items: mapa.get(g).sort((a, b) => limpiar(a.nombre).localeCompare(limpiar(b.nombre)))
        }));
    }

    window.IconosInsumo = { buscar, de, agrupar };
})();
