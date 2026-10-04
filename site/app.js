(function () {
  "use strict";

  var config = window.LunaPublicConfig || {};
  var version = config.version || "an upcoming release";
  var translations = {
    en: {
      actions_label: "Download and play",
      about_title: "About the game",
      about_one: "Hi! I have a daughter named Luna. We love video games and don’t like ads. So we decided to make this game free and ad-free — for everyone, forever. Luna was three and a half when we started making the game, so it’s made for children around that age.",
      about_two: "All the places in the game are fictional, but we’ve been to them. If you recognize any of them, it’s purely a coincidence.",
      download: "Android · APK",
      windows: "Windows x64 · ZIP",
      full_changelog: "Full changelog",
      updates_title: "What’s new",
      back_home: "Back to home",
      email_label: "Email address",
      feedback_link: "Feedback form",
      feedback_title: "Feedback for grown-ups",
      form_intro: "If GitHub is not convenient, you can write to us here.",
      grown_ups: "For grown-ups",
      grown_ups_links: "Grown-ups links",
      issues_button: "Open GitHub Issues",
      issues_intro: "Know GitHub? Please report a problem or suggest an idea in GitHub Issues — it is the main feedback channel. GitHub Issues are public; please don’t share a child’s name, photo, location, or other identifying information.",
      issues_link: "GitHub Issues",
      language_selector: "Language selector",
      license: "License & notices",
      message_label: "Feedback",
      name_label: "Your name",
      play: "Play in browser · Desktop Chrome only",
      privacy: "Formspree and Luna Goes Places receive the name, email address, and feedback you submit. Please don’t share a child’s name, photo, location, or other identifying information.",
      quiet_corner: "A quiet corner",
      send: "Send feedback",
      site_title: "Luna Goes Places",
      source: "Source",
      version: "Version"
    },
    ru: {
      actions_label: "Скачать и играть",
      about_title: "Об игре",
      about_one: "Привет! У меня есть дочь, её зовут Луна. Мы любим компьютерные игры и не любим рекламу. Поэтому мы решили сделать эту игру бесплатной и без рекламы — для всех и навсегда. Когда мы начали делать игру, Луне было три с половиной года, поэтому она рассчитана на детей примерно такого возраста.",
      about_two: "Все локации в игре вымышленные, но мы в них были. Если вы какую-то из них узнали, это чистое совпадение.",
      download: "Android · APK",
      windows: "Windows x64 · ZIP",
      full_changelog: "Полная история обновлений",
      updates_title: "Что нового",
      back_home: "На главную",
      email_label: "Адрес электронной почты",
      feedback_link: "Форма обратной связи",
      feedback_title: "Обратная связь для взрослых",
      form_intro: "Если GitHub вам не подходит, напишите нам здесь.",
      grown_ups: "Для взрослых",
      grown_ups_links: "Ссылки для взрослых",
      issues_button: "Открыть GitHub Issues",
      issues_intro: "Знакомы с GitHub? Сообщите об ошибке или предложите идею в GitHub Issues — это основной канал обратной связи. GitHub Issues общедоступны: пожалуйста, не указывайте имя ребёнка, фотографию, местоположение или другие сведения, по которым его можно узнать.",
      issues_link: "GitHub Issues",
      language_selector: "Выбор языка",
      license: "Лицензия и уведомления",
      message_label: "Сообщение",
      name_label: "Ваше имя",
      play: "Играть в браузере · только Chrome на компьютере",
      privacy: "Formspree и Luna Goes Places получат имя, адрес электронной почты и текст, которые вы отправите. Пожалуйста, не указывайте имя ребёнка, фотографию, местоположение или другие сведения, по которым его можно узнать.",
      quiet_corner: "Тихий уголок",
      send: "Отправить",
      site_title: "Где же Луна?",
      source: "Исходный код",
      version: "Версия"
    }
  };

  function setLink(id, url) {
    var link = document.getElementById(id);
    if (link && url) {
      link.href = url;
    }
  }

  function addParagraphs(container, paragraphs) {
    paragraphs.forEach(function (paragraph) {
      var element = document.createElement("p");
      element.textContent = paragraph;
      container.appendChild(element);
    });
  }

  function showNotes(language) {
    var notes = window.LunaReleaseNotes || [];
    var latest = document.getElementById("latest-note");
    var list = document.getElementById("release-list");
    if (latest) {
      latest.replaceChildren();
      var current = notes.find(function (note) { return note.version === version; });
      document.getElementById("whats-new").hidden = !current;
      if (current) {
        document.getElementById("update-version").textContent = current.version;
        addParagraphs(latest, current[language] || current.en);
      }
    }
    if (list) {
      list.replaceChildren();
      notes.forEach(function (note) {
        var article = document.createElement("article");
        article.id = "version-" + note.version;
        var heading = document.createElement("h2");
        heading.textContent = translations[language].version + " " + note.version;
        article.appendChild(heading);
        addParagraphs(article, note[language] || note.en);
        list.appendChild(article);
      });
    }
  }

  function preferredLanguage() {
    try {
      var saved = window.localStorage.getItem("luna-public-language");
      if (saved && translations[saved]) {
        return saved;
      }
    } catch (error) {
      // A private browsing mode may block local storage; browser preference is enough.
    }

    return (navigator.language || "en").toLowerCase().indexOf("ru") === 0 ? "ru" : "en";
  }

  function setLanguage(language) {
    var words = translations[language] || translations.en;
    var textNodes = document.querySelectorAll("[data-i18n]");
    var ariaNodes = document.querySelectorAll("[data-i18n-aria]");
    var buttons = document.querySelectorAll("[data-language]");
    var index;

    document.documentElement.lang = language;
    for (index = 0; index < textNodes.length; index += 1) {
      textNodes[index].textContent = words[textNodes[index].getAttribute("data-i18n")];
    }
    for (index = 0; index < ariaNodes.length; index += 1) {
      ariaNodes[index].setAttribute("aria-label", words[ariaNodes[index].getAttribute("data-i18n-aria")]);
    }
    for (index = 0; index < buttons.length; index += 1) {
      buttons[index].setAttribute("aria-pressed", buttons[index].getAttribute("data-language") === language ? "true" : "false");
    }
    showNotes(language);
  }

  if (document.getElementById("release-version")) document.getElementById("release-version").textContent = version;
  if (document.getElementById("footer-version")) document.getElementById("footer-version").textContent = version;
  setLink("play-link", config.play_url);
  setLink("apk-link", config.apk_url);
  setLink("windows-link", config.windows_url);
  if (document.getElementById("windows-link")) document.getElementById("windows-link").hidden = !config.windows_url;
  setLink("source-link", config.source_url);
  setLink("license-link", config.license_url);

  setLanguage(preferredLanguage());
  document.addEventListener("click", function (event) {
    var button = event.target.closest("[data-language]");
    if (!button) {
      return;
    }

    var language = button.getAttribute("data-language");
    setLanguage(language);
    try {
      window.localStorage.setItem("luna-public-language", language);
    } catch (error) {
      // Language selection still works if persistence is unavailable.
    }
  });
}());
