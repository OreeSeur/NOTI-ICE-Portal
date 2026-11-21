import { useEffect, useMemo, useState } from "react";

import { AdminMobileCard } from "../../../components/common/AdminMobileCard";
import { AdminTableWrapper } from "../../../components/common/AdminTableWrapper";
import { AudienceSummary } from "../../../components/common/AudienceSummary";
import { CrudActions } from "../../../components/common/CrudActions";
import { EmptyState } from "../../../components/common/EmptyState";
import { PageHeader } from "../../../components/common/PageHeader";
import { SearchInput } from "../../../components/common/SearchInput";
import { StatusBadge } from "../../../components/common/StatusBadge";
import { ConfirmModal } from "../../../components/ui/ConfirmModal";
import { ROUTES, buildRoute } from "../../../constants/routes";
import { useNoticias } from "../../../context/noticias/useNoticias";
import { useToast } from "../../../context/toast/useToast";
import { obtenerNoticias } from "../../../services/noticiasService";
import { buildAudienceSearchText } from "../../../utils/audience";
import { matchesSearch } from "../../../utils/search";

const textoVigencia = (noticia) => {
  if (noticia.expirada) return `Expirada el ${noticia.vigenteHasta}`;
  if (noticia.vigenteHasta) return `Vigente hasta ${noticia.vigenteHasta}`;
  return "Sin vencimiento";
};

export const AdminNoticias = () => {
  const { eliminarNoticia } = useNoticias();
  const { error: mostrarError } = useToast();

  // Este listado incluye las noticias expiradas (la lista pública solo trae las vigentes),
  // para que el administrador pueda renovarlas editando su fecha de vigencia.
  const [noticias, setNoticias] = useState([]);
  const [cargando, setCargando] = useState(true);

  useEffect(() => {
    let cancelado = false;

    obtenerNoticias({ incluirExpiradas: true })
      .then((data) => {
        if (!cancelado) setNoticias(data);
      })
      .catch((err) => {
        if (!cancelado) mostrarError(err.message || "No se pudieron cargar las noticias");
      })
      .finally(() => {
        if (!cancelado) setCargando(false);
      });

    return () => {
      cancelado = true;
    };
  }, [mostrarError]);

  const [search, setSearch] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [noticiaSeleccionado, setNoticiaSeleccionado] = useState(null);

  const noticiasFiltrados = useMemo(
    () =>
      noticias.filter((noticia) =>
        matchesSearch(noticia, ["titulo", "fecha", "categoria", buildAudienceSearchText], search)
      ),
    [noticias, search]
  );

  const abrirModal = (noticia) => {
    setNoticiaSeleccionado(noticia);
    setModalOpen(true);
  };

  const cerrarModal = () => {
    setModalOpen(false);
    setNoticiaSeleccionado(null);
  };

  const confirmarEliminacion = async () => {
    if (!noticiaSeleccionado) return;

    await eliminarNoticia(noticiaSeleccionado.id);
    setNoticias((prev) => prev.filter((item) => item.id !== noticiaSeleccionado.id));
    cerrarModal();
  };

  return (
    <section className="space-y-6">
      <PageHeader
        title="Administración de Noticias"
        description="Gestiona las noticias publicadas en el portal."
      />

      <div className="rounded-xl bg-white p-4 shadow-md dark:bg-slate-800">
        <SearchInput
          value={search}
          onChange={setSearch}
          placeholder="Buscar por título, fecha o categoría..."
        />
      </div>

      <div className="space-y-4 lg:hidden">
        {noticiasFiltrados.length === 0 ? (
          <EmptyState
            title={cargando ? "Cargando noticias..." : "No se encontraron noticias"}
            message={cargando ? undefined : "Prueba con otra búsqueda. Para publicar una noticia, hazlo desde el módulo Noticias."}
          />
        ) : (
          noticiasFiltrados.map((noticia) => (
            <AdminMobileCard
              key={noticia.id}
              title={noticia.titulo || "Noticia sin título"}
              subtitle={`${noticia.fecha || "Sin fecha"} · ${textoVigencia(noticia)}`}
              description={noticia.descripcion}
              badgeLabel={noticia.expirada ? "Expirada" : "Noticia"}
              badgeVariant={noticia.expirada ? "danger" : "primary"}
              item={noticia}
              editTo={buildRoute(ROUTES.ADMIN_NOTICIAS_EDITAR, { id: noticia.id })}
              detailTo={
                noticia.expirada
                  ? undefined
                  : buildRoute(ROUTES.NOTICIA_DETALLE, { id: noticia.id })
              }
              onDelete={() => abrirModal(noticia)}
            />
          ))
        )}
      </div>

      <AdminTableWrapper className="hidden lg:block">
        <table className="w-full min-w-[720px]">
          <thead>
            <tr className="bg-slate-100 dark:bg-slate-700">
              <th className="p-4 text-left">Título</th>
              <th className="p-4 text-left">Fecha</th>
              <th className="p-4 text-left">Vigencia</th>
              <th className="p-4 text-left">Destinatarios</th>
              <th className="p-4 text-center">Acciones</th>
            </tr>
          </thead>

          <tbody>
            {noticiasFiltrados.length === 0 ? (
              <EmptyState
                colSpan={5}
                title={cargando ? "Cargando noticias..." : "No se encontraron noticias"}
                message={cargando ? undefined : "Prueba con otra búsqueda. Para publicar una noticia, hazlo desde el módulo Noticias."}
              />
            ) : (
              noticiasFiltrados.map((noticia) => (
                <tr
                  key={noticia.id}
                  className="border-b border-slate-200 dark:border-slate-700"
                >
                  <td className="p-4 font-medium text-slate-800 dark:text-white">
                    {noticia.titulo || "Noticia sin título"}
                  </td>
                  <td className="p-4 text-slate-600 dark:text-slate-300">
                    {noticia.fecha || "Sin fecha"}
                  </td>
                  <td className="p-4">
                    <StatusBadge
                      label={textoVigencia(noticia)}
                      variant={
                        noticia.expirada
                          ? "danger"
                          : noticia.vigenteHasta
                            ? "success"
                            : "default"
                      }
                    />
                  </td>
                  <td className="p-4">
                    <AudienceSummary item={noticia} compact />
                  </td>
                  <td className="p-4">
                    <CrudActions
                      editTo={buildRoute(ROUTES.ADMIN_NOTICIAS_EDITAR, {
                        id: noticia.id,
                      })}
                      onDelete={() => abrirModal(noticia)}
                    />
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </AdminTableWrapper>

      <ConfirmModal
        isOpen={modalOpen}
        title="Eliminar Noticia"
        message={`¿Deseas eliminar "${
          noticiaSeleccionado?.titulo || "esta noticia"
        }"? Esta acción no se puede deshacer.`}
        confirmLabel="Eliminar noticia"
        onConfirm={confirmarEliminacion}
        onCancel={cerrarModal}
      />
    </section>
  );
};
