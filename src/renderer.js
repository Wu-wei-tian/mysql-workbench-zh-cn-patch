// SPDX-License-Identifier: GPL-2.0-only
// Only AST-selected display literals call this function. No DOM/data rewriting.
(() => {
    const dictionary = /*DICTIONARY*/;
    const language = globalThis.__wbLanguage === 'en' ? 'en' : 'zh-CN';
    Object.defineProperty(globalThis, '__wbT', {
        value: (text, args) => {
            const translated = language === 'zh-CN' && Object.hasOwn(dictionary, text) ? dictionary[text] : text;
            return args ? translated.replace(/\{(\d+)\}/g, (_, n) => String(args[Number(n)])) : translated;
        },
        writable: false,
    });
    document.documentElement.lang = language;
})();
