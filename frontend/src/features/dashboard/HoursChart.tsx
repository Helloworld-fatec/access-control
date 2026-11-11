import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { HourBucket } from "../../shared/types";

const GRANTED = "#1c6b45";
const DENIED = "#B51F2E";
const label = (h: number) => `${String(h).padStart(2, "0")}h`;

/** Acessos por hora. O gráfico não carrega a informação sozinho: há legenda em texto e uma tabela equivalente. */
export default function HoursChart({ data }: { data: HourBucket[] }) {
  const rows = data.map((d) => ({ ...d, label: label(d.hour) }));
  const withData = data.filter((d) => d.granted + d.denied > 0);
  const total = data.reduce((a, d) => a + d.granted + d.denied, 0);

  if (total === 0) return <p className="muted">Nenhum acesso registrado neste dia.</p>;

  return (
    <>
      <div role="img" aria-label="Gráfico de barras empilhadas com acessos liberados e negados por hora do dia. Os mesmos dados estão na tabela abaixo.">
        <ResponsiveContainer width="100%" height={280}>
          <BarChart data={rows} margin={{ top: 8, right: 8, left: -12, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#BBC9D1" vertical={false} />
            <XAxis dataKey="label" tick={{ fontSize: 12, fill: "#4A5E6A" }} interval={1} />
            <YAxis allowDecimals={false} tick={{ fontSize: 12, fill: "#4A5E6A" }} />
            <Tooltip />
            <Legend />
            <Bar dataKey="granted" name="Liberados" stackId="a" fill={GRANTED} isAnimationActive={false} />
            <Bar dataKey="denied" name="Negados" stackId="a" fill={DENIED} isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
      </div>
      <details className="data-table">
        <summary>Ver os dados em tabela</summary>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Hora</th><th>Liberados</th><th>Negados</th></tr></thead>
            <tbody>
              {withData.map((d) => (
                <tr key={d.hour}><td>{label(d.hour)}</td><td className="nums">{d.granted}</td><td className="nums">{d.denied}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </details>
    </>
  );
}
