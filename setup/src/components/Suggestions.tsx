// the "things to try" list under an error, with the ((link:...)) tokens turned into links

import { openUrl } from "@tauri-apps/plugin-opener";
import { parseLinkToken, splitLinks } from "../errors";
import { S } from "../strings";
import { links } from "../links";

export const Suggestions = ({ items }: { items: string[] }) => (
  <div className="suggestions">
    {items.length > 0 && <p className="section-title">{S.hub.suggestionsTitle}</p>}
    {items.length > 0 && (
      <ul className="phone-steps">
        {items.map((item) => (
          <li key={item}>
            {splitLinks(item).map((part, index) => {
              const parsed = parseLinkToken(part);
              if (parsed) {
                return (
                  <button key={index} className="linky" onClick={() => openUrl(parsed.url)}>
                    {parsed.text}
                  </button>
                );
              }
              return <span key={index}>{part}</span>;
            })}
          </li>
        ))}
      </ul>
    )}
    <p className="note">
      {S.hub.support}{" "}
      <button className="linky" onClick={() => openUrl(links.support)}>
        {S.hub.supportLink}
      </button>
    </p>
  </div>
);
