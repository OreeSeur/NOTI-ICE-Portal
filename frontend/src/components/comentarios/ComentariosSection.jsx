import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { MessageCircle, Send, Trash2 } from "lucide-react";

import { EmptyState } from "../common/EmptyState";
import { FormError } from "../common/FormError";
import { LoadingSpinner } from "../common/LoadingSpinner";
import { ConfirmModal } from "../ui/ConfirmModal";
import { ROUTES } from "../../constants/routes";
import { useAuth } from "../../context/auth/useAuth";
import { useToast } from "../../context/toast/useToast";
import {
  crearComentarioApi,
  eliminarComentarioApi,
  obtenerComentarios,
} from "../../services/comentariosService";
import { formatDateLabel } from "../../utils/dates";
import { getFriendlyErrorMessage } from "../../utils/errorMessages";
import { mismoId } from "../../utils/id";
import { canAccessAdmin } from "../../utils/permissions";

const MAX_CARACTERES = 1000;

// Uso: <ComentariosSection key={noticia.id} idNoticia={noticia.id} admiteComentarios={!noticia.expirada} />
// Con key, al cambiar de noticia el componente se reinicia solo.
// Una noticia expirada conserva sus comentarios (para el Administrador y su autor) pero no admite nuevos.
export const ComentariosSection = ({ idNoticia, admiteComentarios = true }) => {
  const { user } = useAuth();
  const toast = useToast();

  const [comentarios, setComentarios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState("");
  const [texto, setTexto] = useState("");
  const [enviando, setEnviando] = useState(false);

  useEffect(() => {
    let cancelado = false;

    obtenerComentarios(idNoticia)
      .then((data) => {
        if (!cancelado) setComentarios(data);
      })
      .catch((err) => {
        if (!cancelado) setError(getFriendlyErrorMessage(err));
      })
      .finally(() => {
        if (!cancelado) setCargando(false);
      });

    return () => {
      cancelado = true;
    };
  }, [idNoticia]);

  const publicar = async (evento) => {
    evento.preventDefault();

    const limpio = texto.trim();
    if (!limpio || enviando) return;

    setEnviando(true);

    try {
      const nuevo = await crearComentarioApi(idNoticia, limpio);
      setComentarios((prev) => [...prev, nuevo]);
      setTexto("");
    } catch (err) {
      toast.error(getFriendlyErrorMessage(err));
    } finally {
      setEnviando(false);
    }
  };

  // Confirmación con el modal del portal (no window.confirm: algunos navegadores bloquean
  // los diálogos nativos y el borrado nunca se enviaba).
  const [porEliminar, setPorEliminar] = useState(null);

  const confirmarEliminacion = async () => {
    const comentario = porEliminar;
    if (!comentario) return;

    try {
      await eliminarComentarioApi(comentario.id);
      setComentarios((prev) => prev.filter((item) => item.id !== comentario.id));
      toast.success("Comentario eliminado");
    } catch (err) {
      toast.error(getFriendlyErrorMessage(err));
    } finally {
      setPorEliminar(null);
    }
  };

  // El backend vuelve a validar esto; aquí solo decide si se muestra el botón
  const puedeEliminar = (comentario) =>
    Boolean(user) && (canAccessAdmin(user) || mismoId(user.id, comentario.idUsuario));

  return (
    <section
      aria-labelledby="titulo-comentarios"
      className="space-y-5 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-700 dark:bg-slate-800 sm:p-8"
    >
      <h2
        id="titulo-comentarios"
        className="flex items-center gap-2 text-lg font-black text-slate-900 dark:text-white"
      >
        <MessageCircle size={20} className="text-[#6F1D46] dark:text-pink-100" />
        Comentarios
        {!cargando && (
          <span className="text-sm font-semibold text-slate-500 dark:text-slate-400">
            ({comentarios.length})
          </span>
        )}
      </h2>

      {!admiteComentarios ? (
        <p className="rounded-2xl bg-slate-50 p-4 text-sm text-slate-600 dark:bg-slate-900/40 dark:text-slate-300">
          Esta noticia ya no está vigente y no admite comentarios nuevos.
        </p>
      ) : user ? (
        <form onSubmit={publicar} className="space-y-3">
          <label htmlFor="nuevo-comentario" className="sr-only">
            Escribe un comentario
          </label>
          <textarea
            id="nuevo-comentario"
            value={texto}
            onChange={(e) => setTexto(e.target.value)}
            maxLength={MAX_CARACTERES}
            rows={3}
            placeholder="Escribe un comentario..."
            className="w-full resize-y rounded-2xl border border-slate-300 bg-white p-3 text-sm text-slate-800 outline-none transition focus:border-[#6F1D46] focus:ring-2 focus:ring-[#6F1D46]/20 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
          />

          <div className="flex items-center justify-between gap-3">
            <span className="text-xs text-slate-500 dark:text-slate-400">
              {texto.length}/{MAX_CARACTERES}
            </span>

            <button
              type="submit"
              disabled={enviando || !texto.trim()}
              className="inline-flex items-center gap-2 rounded-xl bg-[#6F1D46] px-4 py-2 text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Send size={16} />
              {enviando ? "Publicando..." : "Publicar"}
            </button>
          </div>
        </form>
      ) : (
        <p className="rounded-2xl bg-slate-50 p-4 text-sm text-slate-600 dark:bg-slate-900/40 dark:text-slate-300">
          <Link
            to={ROUTES.LOGIN}
            className="font-semibold text-[#6F1D46] underline dark:text-pink-100"
          >
            Inicia sesión
          </Link>{" "}
          para comentar.
        </p>
      )}

      <FormError message={error} />

      {cargando ? (
        <LoadingSpinner label="Cargando comentarios..." />
      ) : comentarios.length === 0 && !error ? (
        <EmptyState
          icon={MessageCircle}
          title="Aún no hay comentarios"
          message="Sé la primera persona en comentar esta noticia."
        />
      ) : (
        <ul className="space-y-3">
          {comentarios.map((comentario) => (
            <li
              key={comentario.id}
              className="rounded-2xl border border-slate-100 bg-slate-50/70 p-4 dark:border-slate-700 dark:bg-slate-900/30"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-sm font-bold text-slate-900 dark:text-white">
                    {comentario.autor}
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400">
                    {formatDateLabel(comentario.fecha)}
                  </p>
                </div>

                {puedeEliminar(comentario) && (
                  <button
                    type="button"
                    onClick={() => setPorEliminar(comentario)}
                    aria-label="Eliminar comentario"
                    className="rounded-lg p-2 text-slate-500 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-900/30"
                  >
                    <Trash2 size={16} />
                  </button>
                )}
              </div>

              {/* React escapa el texto: no se interpreta como HTML */}
              <p className="mt-2 whitespace-pre-line break-words text-sm leading-relaxed text-slate-700 dark:text-slate-300">
                {comentario.texto}
              </p>
            </li>
          ))}
        </ul>
      )}

      <ConfirmModal
        isOpen={Boolean(porEliminar)}
        title="Eliminar comentario"
        message="¿Deseas eliminar este comentario? Dejará de mostrarse en la noticia."
        confirmLabel="Eliminar"
        onConfirm={confirmarEliminacion}
        onCancel={() => setPorEliminar(null)}
      />
    </section>
  );
};
