import React, { useState, useMemo } from 'react';
import { README_ORG_CONTENT } from './readmeContent.ts';
import { 
  Copy, 
  Check, 
  Download, 
  Search, 
  FileText, 
  BookOpen, 
  Terminal, 
  Code2, 
  FolderGit2, 
  ChevronRight, 
  Layers
} from 'lucide-react';

interface Section {
  id: string;
  level: number;
  title: string;
  lineIndex: number;
}

export default function App() {
  const [copiedCode, setCopiedCode] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeSection, setActiveSection] = useState<string>('');
  const [activeTab, setActiveTab] = useState<'reader' | 'files'>('reader');
  const [copiedAll, setCopiedAll] = useState(false);

  // Parse sections for Table of Contents
  const sections = useMemo<Section[]>(() => {
    const lines = README_ORG_CONTENT.split('\n');
    const result: Section[] = [];
    lines.forEach((line, idx) => {
      const match = line.match(/^(\*{1,3})\s+(.*)$/);
      if (match) {
        const level = match[1].length;
        const title = match[2].trim();
        const id = `heading-${idx}-${title.toLowerCase().replace(/[^a-zа-я0-9]+/gi, '-')}`;
        result.push({ id, level, title, lineIndex: idx });
      }
    });
    return result;
  }, []);

  const handleCopy = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedCode(id);
    setTimeout(() => setCopiedCode(null), 2000);
  };

  const handleDownload = () => {
    const blob = new Blob([README_ORG_CONTENT], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'readme.org';
    link.click();
    URL.revokeObjectURL(url);
  };

  const handleCopyFullReadme = () => {
    navigator.clipboard.writeText(README_ORG_CONTENT);
    setCopiedAll(true);
    setTimeout(() => setCopiedAll(false), 2000);
  };

  // Render Org text into structured elements
  const renderOrgContent = () => {
    const lines = README_ORG_CONTENT.split('\n');
    const elements: React.ReactNode[] = [];
    let inSrcBlock = false;
    let srcLanguage = '';
    let srcLines: string[] = [];
    let srcBlockIndex = 0;
    let inTable = false;
    let tableRows: string[][] = [];

    const flushTable = () => {
      if (tableRows.length > 0) {
        const rows = [...tableRows];
        elements.push(
          <div key={`table-${elements.length}`} className="my-6 overflow-x-auto border border-[#313244] rounded bg-[#181825]/90 shadow-lg">
            <table className="w-full text-left text-sm font-mono border-collapse">
              <thead>
                <tr className="border-b border-[#45475a] bg-[#1e1e2e]/90 text-[#cdd6f4]">
                  {rows[0].map((cell, cIdx) => (
                    <th key={cIdx} className="px-4 py-2.5 font-semibold text-[#89b4fa] border-r border-[#313244] last:border-r-0">
                      {cell}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.slice(1).map((row, rIdx) => {
                  // Check if row is separator line like |---|---|
                  if (row.every(c => c.trim().match(/^-+$/))) {
                    return null;
                  }
                  return (
                    <tr 
                      key={rIdx} 
                      className={`border-b border-[#313244]/60 hover:bg-[#313244]/30 transition-colors ${
                        rIdx % 2 === 1 ? 'bg-[#181825]' : 'bg-[#1e1e2e]/40'
                      }`}
                    >
                      {row.map((cell, cIdx) => {
                        // Render styled key commands or code
                        const formatted = cell.replace(/=([^=]+)=/g, '<code class="px-1.5 py-0.5 rounded bg-[#313244] text-[#fab387] font-bold text-xs">$1</code>')
                                              .replace(/~([^~]+)~/g, '<kbd class="px-1.5 py-0.5 rounded bg-[#45475a] text-[#a6e3a1] font-mono text-xs shadow">$1</kbd>');
                        return (
                          <td 
                            key={cIdx} 
                            className="px-4 py-2.5 text-[#bac2de] border-r border-[#313244] last:border-r-0"
                            dangerouslySetInnerHTML={{ __html: formatted }}
                          />
                        );
                      })}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        );
        tableRows = [];
        inTable = false;
      }
    };

    lines.forEach((line, index) => {
      // Check for code blocks
      if (line.startsWith('#+begin_src')) {
        flushTable();
        inSrcBlock = true;
        srcLanguage = line.replace('#+begin_src', '').trim();
        srcLines = [];
        return;
      }

      if (line.startsWith('#+end_src')) {
        inSrcBlock = false;
        const codeText = srcLines.join('\n');
        const blockId = `code-block-${srcBlockIndex++}`;
        elements.push(
          <div key={blockId} className="my-5 rounded-lg border border-[#45475a] bg-[#11111b] overflow-hidden shadow-xl">
            <div className="flex items-center justify-between px-4 py-2 bg-[#181825] border-b border-[#313244] text-xs font-mono text-[#a6adc8]">
              <div className="flex items-center space-x-2">
                <span className="w-2.5 h-2.5 rounded-full bg-[#f38ba8]/80"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-[#f9e2af]/80"></span>
                <span className="w-2.5 h-2.5 rounded-full bg-[#a6e3a1]/80"></span>
                <span className="text-[#89b4fa] font-bold ml-2">#+begin_src {srcLanguage}</span>
              </div>
              <button
                onClick={() => handleCopy(codeText, blockId)}
                className="flex items-center space-x-1.5 px-2.5 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#cdd6f4] transition-colors cursor-pointer"
                title="Копировать код"
              >
                {copiedCode === blockId ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-[#a6e3a1]" />
                    <span className="text-[#a6e3a1]">Скопировано!</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5" />
                    <span>Копировать</span>
                  </>
                )}
              </button>
            </div>
            <pre className="p-4 text-sm font-mono text-[#cdd6f4] overflow-x-auto leading-relaxed">
              <code>{codeText}</code>
            </pre>
          </div>
        );
        return;
      }

      if (inSrcBlock) {
        srcLines.push(line);
        return;
      }

      // Check for table lines
      if (line.trim().startsWith('|')) {
        inTable = true;
        const cells = line
          .trim()
          .slice(1, -1)
          .split('|')
          .map(c => c.trim());
        tableRows.push(cells);
        return;
      } else if (inTable) {
        flushTable();
      }

      // Metadata headers (#+TITLE:, etc.)
      if (line.startsWith('#+')) {
        elements.push(
          <div key={`meta-${index}`} className="text-xs font-mono text-[#6c7086] py-0.5 tracking-wide flex items-center gap-2">
            <span className="text-[#f38ba8] font-bold">{line.split(':')[0]}:</span>
            <span className="text-[#fab387]">{line.substring(line.indexOf(':') + 1).trim()}</span>
          </div>
        );
        return;
      }

      // Headings
      const hMatch = line.match(/^(\*{1,3})\s+(.*)$/);
      if (hMatch) {
        const level = hMatch[1].length;
        const title = hMatch[2].trim();
        const id = `heading-${index}-${title.toLowerCase().replace(/[^a-zа-я0-9]+/gi, '-')}`;

        if (level === 1) {
          elements.push(
            <h1
              id={id}
              key={id}
              className="mt-8 mb-4 pt-4 text-2xl font-bold tracking-tight text-[#89b4fa] border-b border-[#313244] pb-2 flex items-center gap-2 scroll-mt-6"
            >
              <span className="text-[#f38ba8] select-none text-xl font-normal">*</span>
              <span>{title}</span>
            </h1>
          );
        } else if (level === 2) {
          elements.push(
            <h2
              id={id}
              key={id}
              className="mt-6 mb-3 text-lg font-semibold text-[#cba6f7] flex items-center gap-2 scroll-mt-6"
            >
              <span className="text-[#fab387] select-none text-base font-normal">**</span>
              <span>{title}</span>
            </h2>
          );
        } else {
          elements.push(
            <h3
              id={id}
              key={id}
              className="mt-4 mb-2 text-base font-medium text-[#94e2d5] flex items-center gap-2 scroll-mt-6"
            >
              <span className="text-[#a6e3a1] select-none text-sm font-normal">***</span>
              <span>{title}</span>
            </h3>
          );
        }
        return;
      }

      // List items (- or +)
      if (line.match(/^\s*[-+]\s+/)) {
        const content = line.replace(/^\s*[-+]\s+/, '');
        const formatted = content
          .replace(/\*([^*]+)\*/g, '<strong class="text-[#f9e2af] font-semibold">$1</strong>')
          .replace(/=([^=]+)=/g, '<code class="px-1.5 py-0.5 rounded bg-[#313244] text-[#fab387] font-bold text-xs">$1</code>')
          .replace(/~([^~]+)~/g, '<kbd class="px-1.5 py-0.5 rounded bg-[#45475a] text-[#a6e3a1] font-mono text-xs shadow">$1</kbd>');

        elements.push(
          <li key={`list-${index}`} className="ml-6 my-1.5 text-sm leading-relaxed text-[#bac2de] list-disc marker:text-[#89b4fa]">
            <span dangerouslySetInnerHTML={{ __html: formatted }} />
          </li>
        );
        return;
      }

      // Normal paragraph
      if (line.trim().length > 0) {
        const formatted = line
          .replace(/\[\[(.*?)\]\[(.*?)\]\]/g, '<a href="$1" class="text-[#89b4fa] underline hover:text-[#b4befe] decoration-[#89b4fa]/50 underline-offset-2">$2</a>')
          .replace(/`([^`]+)`/g, '<code class="px-1.5 py-0.5 rounded bg-[#313244] text-[#89b4fa] font-mono text-xs">$1</code>')
          .replace(/\*([^*]+)\*/g, '<strong class="text-[#f9e2af] font-semibold">$1</strong>')
          .replace(/=([^=]+)=/g, '<code class="px-1.5 py-0.5 rounded bg-[#313244] text-[#fab387] font-bold text-xs">$1</code>')
          .replace(/~([^~]+)~/g, '<kbd class="px-1.5 py-0.5 rounded bg-[#45475a] text-[#a6e3a1] font-mono text-xs shadow">$1</kbd>');

        elements.push(
          <p key={`p-${index}`} className="my-2.5 text-sm leading-relaxed text-[#cdd6f4]">
            <span dangerouslySetInnerHTML={{ __html: formatted }} />
          </p>
        );
      }
    });

    flushTable();
    return elements;
  };

  // Filter sections if search query is present
  const filteredSections = useMemo(() => {
    if (!searchQuery.trim()) return sections;
    const q = searchQuery.toLowerCase();
    return sections.filter(s => s.title.toLowerCase().includes(q));
  }, [sections, searchQuery]);

  const elispFiles = [
    { name: 'boardgame-org.el', path: 'src.el/boardgame-org.el', desc: 'Главная точка входа, интерактивные команды, меню и автозагрузка' },
    { name: 'boardgame-org-core.el', path: 'src.el/boardgame-org-core.el', desc: 'Структуры данных cl-defstruct, defcustom (./world/) и Git-коммиты' },
    { name: 'boardgame-org-frame.el', path: 'src.el/boardgame-org-frame.el', desc: 'Выделенный 3-оконный Emacs-фрейм (Доска 80% / Лог 80% / Статус 20%)' },
    { name: 'boardgame-org-log.el', path: 'src.el/boardgame-org-log.el', desc: 'Персистентный лог мира <world-name>-log.org и автосохранение' },
    { name: 'boardgame-org-status.el', path: 'src.el/boardgame-org-status.el', desc: 'Буфер *boardgame-status* с динамической палитрой и координатами' },
    { name: 'boardgame-org-drawing.el', path: 'src.el/boardgame-org-drawing.el', desc: 'Минорный режим ZZT рисования сукна, пипетка и замещение текста' },
    { name: 'boardgame-org-marker.el', path: 'src.el/boardgame-org-marker.el', desc: 'Кросс-досочная телепортация курсора и маркеры ^' },
    { name: 'boardgame-org-hand.el', path: 'src.el/boardgame-org-hand.el', desc: 'Рука игрока и универсальный перенос Org-заголовков на доску' },
    { name: 'boardgame-org-test.el', path: 'src.el/boardgame-org-test.el', desc: 'Полный набор автоматизированных регрессионных ERT-тестов' },
  ];

  return (
    <div className="flex h-screen w-screen flex-col bg-[#1e1e2e] text-[#cdd6f4] font-mono select-text">
      {/* Emacs Window Title Bar */}
      <header className="flex h-10 items-center justify-between border-b border-[#313244] bg-[#181825] px-4 text-xs select-none">
        <div className="flex items-center space-x-3">
          <div className="flex items-center space-x-1.5">
            <span className="h-3 w-3 rounded-full bg-[#f38ba8]/90"></span>
            <span className="h-3 w-3 rounded-full bg-[#f9e2af]/90"></span>
            <span className="h-3 w-3 rounded-full bg-[#a6e3a1]/90"></span>
          </div>
          <div className="flex items-center space-x-2 bg-[#1e1e2e] px-3 py-1 rounded border border-[#313244] shadow-inner">
            <FileText className="w-3.5 h-3.5 text-[#89b4fa]" />
            <span className="font-semibold text-[#cdd6f4]">readme.org</span>
            <span className="text-[10px] uppercase font-bold text-[#a6adc8] bg-[#313244] px-1 rounded">Org</span>
          </div>
          <span className="hidden sm:inline text-[#6c7086]">~/Dev/emacs/boardgame-org/readme.org</span>
        </div>

        <div className="flex items-center space-x-2">
          <button
            onClick={() => setActiveTab('reader')}
            className={`flex items-center space-x-1.5 px-3 py-1 rounded transition-colors text-xs cursor-pointer ${
              activeTab === 'reader'
                ? 'bg-[#89b4fa] text-[#11111b] font-bold shadow'
                : 'bg-[#313244] hover:bg-[#45475a] text-[#cdd6f4]'
            }`}
          >
            <BookOpen className="w-3.5 h-3.5" />
            <span>Документация</span>
          </button>

          <button
            onClick={() => setActiveTab('files')}
            className={`flex items-center space-x-1.5 px-3 py-1 rounded transition-colors text-xs cursor-pointer ${
              activeTab === 'files'
                ? 'bg-[#89b4fa] text-[#11111b] font-bold shadow'
                : 'bg-[#313244] hover:bg-[#45475a] text-[#cdd6f4]'
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Файлы пакета (src.el/)</span>
          </button>

          <button
            onClick={handleCopyFullReadme}
            className="flex items-center space-x-1.5 px-2.5 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#cdd6f4] transition-colors cursor-pointer text-xs"
            title="Скопировать всё содержимое readme.org"
          >
            {copiedAll ? <Check className="w-3.5 h-3.5 text-[#a6e3a1]" /> : <Copy className="w-3.5 h-3.5" />}
            <span className="hidden md:inline">{copiedAll ? 'Скопировано!' : 'Копировать Org'}</span>
          </button>

          <button
            onClick={handleDownload}
            className="flex items-center space-x-1.5 px-2.5 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#cdd6f4] transition-colors cursor-pointer text-xs"
            title="Скачать readme.org"
          >
            <Download className="w-3.5 h-3.5 text-[#89b4fa]" />
            <span className="hidden md:inline">Скачать</span>
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <div className="flex flex-1 overflow-hidden">
        {activeTab === 'reader' ? (
          <>
            {/* Sidebar Table of Contents */}
            <aside className="w-72 hidden md:flex flex-col border-r border-[#313244] bg-[#181825]/95 text-xs select-none">
              <div className="p-3 border-b border-[#313244]">
                <div className="relative">
                  <Search className="w-3.5 h-3.5 text-[#6c7086] absolute left-2.5 top-2.5" />
                  <input
                    type="text"
                    placeholder="Поиск по разделам..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full pl-8 pr-3 py-1.5 rounded bg-[#1e1e2e] border border-[#313244] text-[#cdd6f4] placeholder-[#6c7086] text-xs focus:outline-none focus:border-[#89b4fa]"
                  />
                </div>
              </div>

              <div className="p-3 text-[11px] font-bold text-[#89b4fa] uppercase tracking-wider flex items-center justify-between">
                <span>Оглавление (TOC)</span>
                <span className="text-[#6c7086]">{filteredSections.length}</span>
              </div>

              <nav className="flex-1 overflow-y-auto px-2 pb-4 space-y-0.5">
                {filteredSections.map((sec) => (
                  <a
                    key={sec.id}
                    href={`#${sec.id}`}
                    onClick={() => setActiveSection(sec.id)}
                    className={`flex items-center space-x-1.5 px-2 py-1.5 rounded transition-colors group ${
                      activeSection === sec.id
                        ? 'bg-[#313244] text-[#89b4fa] font-semibold'
                        : 'text-[#a6adc8] hover:bg-[#313244]/60 hover:text-[#cdd6f4]'
                    } ${sec.level === 2 ? 'pl-5 text-[11px]' : ''} ${sec.level === 3 ? 'pl-8 text-[10px]' : ''}`}
                  >
                    <ChevronRight className={`w-3 h-3 text-[#6c7086] group-hover:text-[#89b4fa] shrink-0 ${sec.level === 1 ? 'text-[#89b4fa]' : ''}`} />
                    <span className="truncate">{sec.title}</span>
                  </a>
                ))}
              </nav>

              <div className="p-3 border-t border-[#313244] bg-[#11111b]/60 text-[11px] text-[#6c7086]">
                <div className="flex items-center gap-1.5 mb-1 text-[#a6adc8]">
                  <Terminal className="w-3.5 h-3.5 text-[#a6e3a1]" />
                  <span>Emacs Lisp Engine</span>
                </div>
                <p>Все модули находятся в <code className="text-[#fab387]">src.el/</code>.</p>
              </div>
            </aside>

            {/* Document Body */}
            <main className="flex-1 overflow-y-auto px-6 md:px-12 py-8 max-w-4xl mx-auto w-full">
              {/* Emacs Buffer Header Decoration */}
              <div className="mb-6 pb-4 border-b border-[#313244]/80 flex flex-wrap items-center justify-between gap-2 text-xs text-[#a6adc8]">
                <div className="flex items-center gap-2">
                  <span className="px-2 py-0.5 rounded bg-[#313244] text-[#fab387] font-semibold">Org Mode</span>
                  <span className="text-[#6c7086]">•</span>
                  <span>Кодировка: UTF-8</span>
                  <span className="text-[#6c7086]">•</span>
                  <span>Спецификация: 100% соотв. boardgame-org-interface.md</span>
                </div>
                <div className="flex items-center gap-1.5 text-[#a6e3a1]">
                  <FolderGit2 className="w-3.5 h-3.5" />
                  <span>Мир по умолчанию: ./world/</span>
                </div>
              </div>

              {/* Rendered Org Document */}
              <article className="prose prose-invert max-w-none">
                {renderOrgContent()}
              </article>
            </main>
          </>
        ) : (
          /* Package Manifest / Files View */
          <main className="flex-1 overflow-y-auto p-6 md:p-12 max-w-5xl mx-auto w-full">
            <div className="mb-8">
              <h1 className="text-2xl font-bold text-[#89b4fa] flex items-center gap-2 mb-2">
                <Code2 className="w-6 h-6 text-[#a6e3a1]" />
                <span>Архитектура пакета Emacs Lisp (каталог src.el/)</span>
              </h1>
              <p className="text-sm text-[#a6adc8] leading-relaxed">
                Пакет полностью модульный, соответствует спецификациям <code className="text-[#fab387]">boardgame-org.md</code> и <code className="text-[#fab387]">boardgame-org-interface.md</code>, оформлен по строгим стандартам MELPA/ELPA с autoload cookies и готов к использованию в любой инсталляции Emacs 27+.
              </p>
            </div>

            <div className="grid grid-cols-1 gap-4">
              {elispFiles.map((file) => (
                <div
                  key={file.name}
                  className="rounded-lg border border-[#313244] bg-[#181825] p-4 hover:border-[#89b4fa]/60 transition-colors shadow-md"
                >
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="p-1.5 rounded bg-[#313244] text-[#89b4fa]">
                        <FileText className="w-4 h-4" />
                      </span>
                      <span className="font-bold text-[#cdd6f4]">{file.name}</span>
                      <span className="text-xs text-[#6c7086]">({file.path})</span>
                    </div>
                    <span className="text-xs px-2 py-0.5 rounded bg-[#a6e3a1]/10 text-[#a6e3a1] border border-[#a6e3a1]/20">
                      MELPA Ready
                    </span>
                  </div>
                  <p className="text-xs text-[#bac2de] leading-relaxed pl-8">
                    {file.desc}
                  </p>
                </div>
              ))}
            </div>

            <div className="mt-8 p-4 rounded-lg border border-[#45475a] bg-[#11111b] text-xs font-mono space-y-2">
              <div className="text-[#89b4fa] font-bold flex items-center gap-2">
                <Terminal className="w-4 h-4 text-[#a6e3a1]" />
                <span>Запуск тестов ERT в пакетном режиме:</span>
              </div>
              <pre className="p-3 rounded bg-[#181825] text-[#a6e3a1] overflow-x-auto">
                emacs -batch -l src.el/boardgame-org-test.el -f ert-run-tests-batch-and-exit
              </pre>
            </div>
          </main>
        )}
      </div>

      {/* Emacs Modeline Footer */}
      <footer className="border-t border-[#313244] bg-[#11111b] text-xs font-mono select-none">
        <div className="flex items-center justify-between px-3 py-1 bg-[#181825] border-b border-[#313244] text-[#a6adc8]">
          <div className="flex items-center space-x-3">
            <span className="font-bold text-[#f38ba8]">-UU-:---</span>
            <span className="text-[#89b4fa] font-semibold">readme.org</span>
            <span className="text-[#a6adc8]">(Org Emacs-Standard)</span>
            <span className="hidden sm:inline text-[#6c7086]">[Dedicated Frame: make-frame | 3-Window Layout]</span>
          </div>
          <div className="flex items-center space-x-4 text-[11px]">
            <span>L1 C1</span>
            <span className="text-[#a6e3a1]">All</span>
            <span className="text-[#f9e2af]">Default: ./world/</span>
          </div>
        </div>
        <div className="px-3 py-1 text-[11px] text-[#6c7086] flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <span className="text-[#cba6f7] font-semibold">M-x</span>
            <span className="text-[#cdd6f4]">boardgame-start</span>
            <span className="text-[#6c7086]">— Запуск игрового фрейма в Emacs</span>
          </div>
          <span className="text-[#fab387]">boardgame.org v1.0.0</span>
        </div>
      </footer>
    </div>
  );
}
