import React, { useState, useMemo } from 'react';
import { README_ORG_CONTENT } from './readmeContent';
import {
  FileText,
  Copy,
  Check,
  Download,
  BookOpen,
  ChevronRight,
  ChevronDown,
  Terminal,
  ExternalLink,
  Search,
  List
} from 'lucide-react';

interface TocItem {
  id: string;
  title: string;
  level: number;
}

export function App() {
  const [copiedIndex, setCopiedIndex] = useState<number | null>(null);
  const [tocOpen, setTocOpen] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [collapsedSections, setCollapsedSections] = useState<Record<string, boolean>>({});

  // Parse Table of Contents from README_ORG_CONTENT
  const tocItems = useMemo(() => {
    const items: TocItem[] = [];
    const lines = README_ORG_CONTENT.split('\n');
    lines.forEach((line) => {
      const match = line.match(/^(\*{1,3})\s+(.+)$/);
      if (match) {
        const level = match[1].length;
        const title = match[2].trim();
        const id = title.toLowerCase().replace(/[^a-z0-9а-яё]+/gi, '-');
        items.push({ id, title, level });
      }
    });
    return items;
  }, []);

  const handleCopy = (text: string, index: number) => {
    navigator.clipboard.writeText(text);
    setCopiedIndex(index);
    setTimeout(() => setCopiedIndex(null), 2000);
  };

  const handleDownloadPackage = () => {
    // Generate text bundle with all elisp files
    const manifest = `boardgame-org Emacs Lisp package files:
Available in the repository under:
  src.el/boardgame-org.el
  src.el/boardgame-org-core.el
  src.el/boardgame-org-object.el
  src.el/boardgame-org-stack.el
  src.el/boardgame-org-container.el
  src.el/boardgame-org-hand.el
  src.el/boardgame-org-board.el
  src.el/boardgame-org-render.el
  src.el/boardgame-org-test.el
  readme.org
`;
    const blob = new Blob([manifest], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'boardgame-org-manifest.txt';
    a.click();
    URL.revokeObjectURL(url);
  };

  const toggleSection = (id: string) => {
    setCollapsedSections((prev) => ({
      ...prev,
      [id]: !prev[id],
    }));
  };

  // Render Org text with syntax highlighting
  const renderOrgContent = () => {
    const lines = README_ORG_CONTENT.split('\n');
    const elements: React.ReactNode[] = [];
    let inSrcBlock = false;
    let srcLang = '';
    let srcBuffer: string[] = [];
    let inQuote = false;
    let quoteBuffer: string[] = [];
    let inTable = false;
    let tableBuffer: string[] = [];
    let srcBlockCounter = 0;

    const flushTable = (key: string) => {
      if (tableBuffer.length === 0) return;
      const rows = [...tableBuffer];
      tableBuffer = [];
      elements.push(
        <div key={key} className="my-4 overflow-x-auto rounded border border-[#3f444a] bg-[#21242b] p-2">
          <table className="w-full font-mono text-xs border-collapse">
            <tbody>
              {rows.map((r, rIdx) => {
                if (r.includes('---')) {
                  return (
                    <tr key={rIdx} className="border-b border-[#3f444a]">
                      <td colSpan={10} className="py-0.5" />
                    </tr>
                  );
                }
                const cols = r.split('|').filter((_, idx, arr) => idx > 0 && idx < arr.length - 1);
                const isHeader = rIdx === 0;
                return (
                  <tr
                    key={rIdx}
                    className={`transition-colors ${
                      isHeader
                        ? 'bg-[#282c34] font-bold text-[#51afef]'
                        : 'text-[#bbc2cf] hover:bg-[#282c34]/60'
                    }`}
                  >
                    {cols.map((col, cIdx) => (
                      <td key={cIdx} className="px-3 py-1.5 border-r border-[#3f444a] last:border-r-0 whitespace-pre">
                        {col.trim()}
                      </td>
                    ))}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      );
    };

    const flushSrcBlock = (key: string) => {
      if (srcBuffer.length === 0) return;
      const code = srcBuffer.join('\n');
      const blockIdx = srcBlockCounter++;
      srcBuffer = [];
      elements.push(
        <div key={key} className="my-3 rounded-lg border border-[#3f444a] bg-[#1e2227] overflow-hidden group shadow-lg">
          <div className="flex items-center justify-between px-3 py-1.5 bg-[#21242b] border-b border-[#3f444a] text-[11px] font-mono">
            <span className="text-[#98be65] font-semibold flex items-center gap-1.5">
              <Terminal className="w-3.5 h-3.5 text-[#51afef]" />
              {srcLang || 'emacs-lisp'}
            </span>
            <button
              onClick={() => handleCopy(code, blockIdx)}
              className="flex items-center gap-1 px-2 py-0.5 rounded bg-[#282c34] hover:bg-[#3f444a] text-[#bbc2cf] hover:text-[#51afef] transition-colors"
              title="Copy code block"
            >
              {copiedIndex === blockIdx ? (
                <>
                  <Check className="w-3 h-3 text-[#98be65]" />
                  <span className="text-[#98be65]">Copied</span>
                </>
              ) : (
                <>
                  <Copy className="w-3 h-3" />
                  <span>Copy</span>
                </>
              )}
            </button>
          </div>
          <pre className="p-3 font-mono text-xs text-[#bbc2cf] overflow-x-auto leading-relaxed whitespace-pre selection:bg-[#3e4451]">
            {code}
          </pre>
        </div>
      );
    };

    const flushQuote = (key: string) => {
      if (quoteBuffer.length === 0) return;
      const text = quoteBuffer.join('\n');
      quoteBuffer = [];
      elements.push(
        <blockquote
          key={key}
          className="my-3 pl-4 py-2 border-l-4 border-[#ecbe7b] bg-[#21242b]/80 rounded-r text-sm text-[#e5c07b] font-mono italic"
        >
          {text}
        </blockquote>
      );
    };

    lines.forEach((line, idx) => {
      // Source block bounds
      if (line.startsWith('#+begin_src')) {
        flushTable(`table-before-src-${idx}`);
        flushQuote(`quote-before-src-${idx}`);
        inSrcBlock = true;
        srcLang = line.replace('#+begin_src', '').trim();
        return;
      }
      if (line.startsWith('#+end_src')) {
        inSrcBlock = false;
        flushSrcBlock(`src-${idx}`);
        return;
      }
      if (inSrcBlock) {
        srcBuffer.push(line);
        return;
      }

      // Quote block bounds
      if (line.startsWith('#+BEGIN_QUOTE')) {
        flushTable(`table-before-quote-${idx}`);
        inQuote = true;
        return;
      }
      if (line.startsWith('#+END_QUOTE')) {
        inQuote = false;
        flushQuote(`quote-${idx}`);
        return;
      }
      if (inQuote) {
        quoteBuffer.push(line);
        return;
      }

      // Table rows
      if (line.trim().startsWith('|')) {
        inTable = true;
        tableBuffer.push(line.trim());
        return;
      } else if (inTable) {
        inTable = false;
        flushTable(`table-${idx}`);
      }

      // Document headers (#+TITLE, #+AUTHOR, etc)
      if (line.startsWith('#+')) {
        elements.push(
          <div key={idx} className="text-[#5c6370] font-mono text-xs py-0.5">
            {line}
          </div>
        );
        return;
      }

      // Org Headings
      const h1Match = line.match(/^\*\s+(.+)$/);
      if (h1Match) {
        const title = h1Match[1];
        const id = title.toLowerCase().replace(/[^a-z0-9а-яё]+/gi, '-');
        elements.push(
          <h1
            key={idx}
            id={id}
            className="text-xl font-bold text-[#51afef] mt-8 mb-3 pb-1 border-b border-[#3f444a] flex items-center gap-2 cursor-pointer group"
            onClick={() => toggleSection(id)}
          >
            <span className="text-[#5c6370] text-sm group-hover:text-[#51afef] transition-colors">*</span>
            <span>{title}</span>
          </h1>
        );
        return;
      }

      const h2Match = line.match(/^\*\*\s+(.+)$/);
      if (h2Match) {
        const title = h2Match[1];
        const id = title.toLowerCase().replace(/[^a-z0-9а-яё]+/gi, '-');
        elements.push(
          <h2
            key={idx}
            id={id}
            className="text-base font-bold text-[#98be65] mt-6 mb-2 flex items-center gap-2 pl-2"
          >
            <span className="text-[#5c6370] text-xs">**</span>
            <span>{title}</span>
          </h2>
        );
        return;
      }

      const h3Match = line.match(/^\*\*\*\s+(.+)$/);
      if (h3Match) {
        const title = h3Match[1];
        elements.push(
          <h3
            key={idx}
            className="text-sm font-semibold text-[#ecbe7b] mt-4 mb-1 pl-4 flex items-center gap-2"
          >
            <span className="text-[#5c6370] text-xs">***</span>
            <span>{title}</span>
          </h3>
        );
        return;
      }

      // Numbered or bullet list items
      if (line.trim().match(/^[0-9]+\.\s+/) || line.trim().startsWith('- ')) {
        elements.push(
          <div key={idx} className="pl-4 py-0.5 text-xs text-[#bbc2cf] font-mono leading-relaxed">
            {line}
          </div>
        );
        return;
      }

      // Regular text paragraph
      if (line.trim()) {
        elements.push(
          <p key={idx} className="text-xs text-[#abb2bf] font-mono py-1 leading-relaxed">
            {line}
          </p>
        );
      } else {
        elements.push(<div key={idx} className="h-2" />);
      }
    });

    flushTable('final-table');
    flushSrcBlock('final-src');
    flushQuote('final-quote');

    return elements;
  };

  return (
    <div className="flex flex-col h-screen w-screen bg-[#1e2227] text-[#bbc2cf] font-mono select-none overflow-hidden">
      {/* Top Header / Doom Emacs Modeline */}
      <header className="flex items-center justify-between px-4 py-2 bg-[#21242b] border-b border-[#3f444a] text-xs select-none">
        <div className="flex items-center gap-3">
          <div className="w-5 h-5 rounded bg-[#51afef]/20 text-[#51afef] flex items-center justify-center font-bold text-xs border border-[#51afef]/40">
            λ
          </div>
          <div className="flex items-center gap-2">
            <span className="font-bold text-[#abb2bf]">boardgame.org</span>
            <span className="text-[#5c6370]">|</span>
            <span className="text-[#51afef] font-semibold">readme.org</span>
            <span className="px-1.5 py-0.2 rounded bg-[#282c34] text-[#98be65] text-[10px] font-mono border border-[#3f444a]">
              (Org-mode Reader)
            </span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setTocOpen(!tocOpen)}
            className={`flex items-center gap-1.5 px-2.5 py-1 rounded transition-colors text-xs font-mono border ${
              tocOpen
                ? 'bg-[#51afef]/20 border-[#51afef]/40 text-[#51afef]'
                : 'bg-[#282c34] border-[#3f444a] text-[#5c6370] hover:text-[#bbc2cf]'
            }`}
            title="Toggle Table of Contents"
          >
            <List className="w-3.5 h-3.5" />
            <span>Оглавление</span>
          </button>

          <button
            onClick={handleDownloadPackage}
            className="flex items-center gap-1.5 px-3 py-1 rounded bg-[#98be65]/20 hover:bg-[#98be65]/30 text-[#98be65] transition-colors text-xs font-mono border border-[#98be65]/40"
            title="Download package files information"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Пакет src.el/</span>
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <div className="flex-1 flex overflow-hidden">
        {/* Table of Contents Sidebar */}
        {tocOpen && (
          <aside className="w-72 bg-[#21242b] border-r border-[#3f444a] flex flex-col overflow-hidden text-xs">
            <div className="p-3 border-b border-[#3f444a] flex items-center justify-between">
              <span className="font-bold text-[#51afef] uppercase tracking-wider text-[11px] flex items-center gap-1.5">
                <BookOpen className="w-3.5 h-3.5 text-[#51afef]" />
                Оглавление документа
              </span>
              <span className="text-[10px] text-[#5c6370]">{tocItems.length} разделов</span>
            </div>

            <div className="flex-1 overflow-y-auto p-2 space-y-1">
              {tocItems.map((item, idx) => (
                <a
                  key={idx}
                  href={`#${item.id}`}
                  className={`block px-2 py-1 rounded transition-colors truncate hover:bg-[#282c34] ${
                    item.level === 1
                      ? 'text-[#51afef] font-semibold text-xs'
                      : item.level === 2
                      ? 'text-[#98be65] pl-4 text-[11px]'
                      : 'text-[#ecbe7b] pl-6 text-[10px]'
                  }`}
                >
                  {item.title}
                </a>
              ))}
            </div>

            <div className="p-3 bg-[#1e2227] border-t border-[#3f444a] text-[10px] text-[#5c6370]">
              Пакет расположен в <code className="text-[#da8548]">src.el/</code>
            </div>
          </aside>
        )}

        {/* Org Document Main Reader Viewport */}
        <main className="flex-1 overflow-y-auto p-6 md:p-8 bg-[#282c34] select-text">
          <div className="max-w-4xl mx-auto space-y-1">
            {renderOrgContent()}
          </div>
        </main>
      </div>

      {/* Emacs Authentic Modeline Footer */}
      <footer className="px-4 py-1 bg-[#21242b] border-t border-[#3f444a] flex items-center justify-between text-[11px] text-[#5c6370] select-none font-mono">
        <div className="flex items-center gap-3">
          <span className="text-[#51afef] font-bold">-U:---</span>
          <span className="text-[#abb2bf] font-semibold">readme.org</span>
          <span>(Org View)</span>
          <span>[UTF-8 Unix]</span>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-[#98be65]">Emacs Lisp: src.el/</span>
          <span>boardgame-org v1.0.0</span>
          <span>All</span>
        </div>
      </footer>
    </div>
  );
}

export default App;
