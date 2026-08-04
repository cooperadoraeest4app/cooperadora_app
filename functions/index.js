const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const { google } = require('googleapis');

admin.initializeApp();

// Configuración OAuth2
const oauth2Client = new google.auth.OAuth2(
  process.env.GMAIL_CLIENT_ID,
  process.env.GMAIL_CLIENT_SECRET,
  'https://developers.google.com/oauthplayground'
);

oauth2Client.setCredentials({
  refresh_token: process.env.GMAIL_REFRESH_TOKEN,
});

// Crear transporter de nodemailer
async function crearTransporter() {
  const accessToken = await oauth2Client.getAccessToken();
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      type: 'OAuth2',
      user: process.env.GMAIL_EMAIL,
      clientId: process.env.GMAIL_CLIENT_ID,
      clientSecret: process.env.GMAIL_CLIENT_SECRET,
      refreshToken: process.env.GMAIL_REFRESH_TOKEN,
      accessToken: accessToken.token,
    },
  });
}

// ─── Cloud Function: enviar email al confirmar/rechazar pago de cuota ───
exports.onPagoCuotaConfirmado = functions.firestore.onDocumentUpdated(
  'pagos_pendientes/{pagoId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Solo disparar cuando el estado cambia a 'confirmado' o 'rechazado'
    if (before.estado === after.estado) return null;
    if (after.estado !== 'confirmado' && after.estado !== 'rechazado') return null;

    try {
      // Obtener datos del usuario (email del socio)
      const usuarioSnap = await admin.firestore()
        .collection('usuarios')
        .where('socioId', '==', after.socioId)
        .limit(1)
        .get();

      if (usuarioSnap.empty) {
        console.log('[Email] No se encontró usuario para socioId:', after.socioId);
        return null;
      }

      const usuarioData = usuarioSnap.docs[0].data();
      const emailDestino = usuarioData.email;

      if (!emailDestino) {
        console.log('[Email] Usuario sin email:', usuarioSnap.docs[0].id);
        return null;
      }

      // Obtener nombre del socio
      const personaSnap = await admin.firestore()
        .collection('personas')
        .doc(usuarioData.personaId)
        .get();
      const persona = personaSnap.data();
      const nombreSocio = persona
        ? `${persona.nombre} ${persona.apellido}`
        : 'Socio/a';

      // Obtener nombre de quien confirmó/rechazó
      const confirmadorSnap = await admin.firestore()
        .collection('usuarios')
        .doc(after.usuarioConfirmacionId)
        .get();
      const confirmadorData = confirmadorSnap.data();
      const confirmadorPersonaSnap = confirmadorData
        ? await admin.firestore()
            .collection('personas')
            .doc(confirmadorData.personaId)
            .get()
        : null;
      const nombreConfirmador = confirmadorPersonaSnap?.data()
        ? `${confirmadorPersonaSnap.data().nombre} ${confirmadorPersonaSnap.data().apellido}`
        : 'Un administrador';

      // Formatear monto
      const monto = new Intl.NumberFormat('es-AR', {
        style: 'currency',
        currency: 'ARS',
      }).format(after.monto);

      // Formatear fecha
      const fechaPago = after.fechaPago.toDate().toLocaleDateString('es-AR');

      // Armar email según estado
      const esConfirmado = after.estado === 'confirmado';

      const asunto = esConfirmado
        ? '✅ Tu pago de cuota fue confirmado — Cooperadora EEST N°4'
        : '❌ Tu pago de cuota fue rechazado — Cooperadora EEST N°4';

      const cuerpoHtml = esConfirmado
        ? `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: #1A3A5C; padding: 20px; text-align: center;">
              <h2 style="color: white; margin: 0;">Cooperadora Escolar</h2>
              <p style="color: rgba(255,255,255,0.7); margin: 4px 0 0;">EEST N°4 — Burzaco</p>
            </div>
            <div style="padding: 24px; background: #f9f9f9;">
              <p style="font-size: 16px;">Hola <strong>${nombreSocio}</strong>,</p>
              <p>Tu pago de cuota social fue <strong style="color: #27AE60;">confirmado</strong> exitosamente.</p>
              <div style="background: white; border: 1px solid #d6eff9; border-radius: 8px; padding: 16px; margin: 16px 0;">
                <p style="margin: 4px 0;"><strong>Monto:</strong> ${monto}</p>
                <p style="margin: 4px 0;"><strong>Fecha de pago:</strong> ${fechaPago}</p>
                <p style="margin: 4px 0;"><strong>Confirmado por:</strong> ${nombreConfirmador}</p>
              </div>
              <p>Podés ver tu historial de pagos ingresando a la app:</p>
              <div style="text-align: center; margin: 24px 0;">
                <a href="https://cooperadora-app.web.app"
                   style="background: #2E9E7A; color: white; padding: 12px 24px;
                          border-radius: 8px; text-decoration: none; font-weight: bold;">
                  Ir a la app
                </a>
              </div>
              <p style="color: #6B7A99; font-size: 13px;">Gracias por tu contribución a la Cooperadora.</p>
            </div>
            <div style="background: #1A3A5C; padding: 12px; text-align: center;">
              <p style="color: rgba(255,255,255,0.6); font-size: 12px; margin: 0;">
                Cooperadora EEST N°4 — cooperadora-app.web.app
              </p>
            </div>
          </div>
        `
        : `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: #1A3A5C; padding: 20px; text-align: center;">
              <h2 style="color: white; margin: 0;">Cooperadora Escolar</h2>
              <p style="color: rgba(255,255,255,0.7); margin: 4px 0 0;">EEST N°4 — Burzaco</p>
            </div>
            <div style="padding: 24px; background: #f9f9f9;">
              <p style="font-size: 16px;">Hola <strong>${nombreSocio}</strong>,</p>
              <p>Tu pago de cuota social fue <strong style="color: #E74C3C;">rechazado</strong>.</p>
              <div style="background: white; border: 1px solid #ffd6d6; border-radius: 8px; padding: 16px; margin: 16px 0;">
                <p style="margin: 4px 0;"><strong>Monto declarado:</strong> ${monto}</p>
                <p style="margin: 4px 0;"><strong>Fecha de pago:</strong> ${fechaPago}</p>
                <p style="margin: 4px 0;"><strong>Motivo del rechazo:</strong> ${after.motivoRechazo ?? 'Sin especificar'}</p>
                <p style="margin: 4px 0;"><strong>Rechazado por:</strong> ${nombreConfirmador}</p>
              </div>
              <p>Por favor revisá el comprobante y volvé a declarar el pago desde la app.</p>
              <div style="text-align: center; margin: 24px 0;">
                <a href="https://cooperadora-app.web.app"
                   style="background: #2E6DA4; color: white; padding: 12px 24px;
                          border-radius: 8px; text-decoration: none; font-weight: bold;">
                  Ir a la app
                </a>
              </div>
              <p style="color: #6B7A99; font-size: 13px;">
                Si creés que es un error, contactá a la Cooperadora.
              </p>
            </div>
            <div style="background: #1A3A5C; padding: 12px; text-align: center;">
              <p style="color: rgba(255,255,255,0.6); font-size: 12px; margin: 0;">
                Cooperadora EEST N°4 — cooperadora-app.web.app
              </p>
            </div>
          </div>
        `;

      // Enviar email
      const transporter = await crearTransporter();
      await transporter.sendMail({
        from: `Cooperadora EEST N°4 <${process.env.GMAIL_EMAIL}>`,
        to: emailDestino,
        cc: process.env.GMAIL_EMAIL,
        subject: asunto,
        html: cuerpoHtml,
      });

      console.log(`[Email] Enviado a ${emailDestino} (cc: ${process.env.GMAIL_EMAIL}) — estado: ${after.estado}`);
      return null;

    } catch (error) {
      console.error('[Email] Error al enviar:', error);
      return null;
    }
  }
);

// ─── Cloud Function: votación aprobada → proyecto en_curso / presupuesto items ─
exports.onVotacionAprobada = functions.firestore.onDocumentUpdated(
  'votaciones/{votacionId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.estado === after.estado) return null;
    if (after.estado !== 'aprobada') return null;

    const tipo = after.tipo;
    const objetoId = after.objetoId;

    try {
      if (tipo === 'proyecto') {
        await admin.firestore()
          .collection('proyectos')
          .doc(objetoId)
          .update({ estado: 'en_curso' });
        console.log(`[VotacionAprobada] Proyecto ${objetoId} → en_curso`);

        const sociosSnap = await admin.firestore()
          .collection('socios')
          .where('activo', '==', true)
          .get();

        const batch = admin.firestore().batch();
        for (const socio of sociosSnap.docs) {
          const notifRef = admin.firestore().collection('notificaciones').doc();
          batch.set(notifRef, {
            tipo: 'proyecto_aprobado',
            titulo: 'Proyecto aprobado',
            mensaje: 'El proyecto fue aprobado por votación y pasa a estar En Curso.',
            destinatarioRol: 'socio',
            destinatarioId: socio.id,
            referenciaId: objetoId,
            leida: false,
            fechaCreacion: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        console.log(`[VotacionAprobada] Notificaciones enviadas a ${sociosSnap.docs.length} socios`);

      } else if (tipo === 'presupuesto') {
        const itemsSnap = await admin.firestore()
          .collection('items_proyecto')
          .where('presupuestosIds', 'array-contains', objetoId)
          .get();

        if (!itemsSnap.empty) {
          const batchItems = admin.firestore().batch();
          for (const doc of itemsSnap.docs) {
            const estadoActual = doc.data().estado;
            if (estadoActual !== 'comprado') {
              batchItems.update(doc.ref, {
                estado: 'presupuestos_aprobados',
                estadoAnterior: estadoActual,
                presupuestoAprobadoId: objetoId,
              });
            }
          }
          await batchItems.commit();
          console.log(`[VotacionAprobada] ${itemsSnap.docs.length} ítems → presupuestos_aprobados`);
        }
      }
    } catch (error) {
      console.error('[VotacionAprobada] Error:', error);
    }
    return null;
  }
);

// ─── Cloud Function: votación rechazada → proyecto cancelado ───────────────
exports.onVotacionRechazada = functions.firestore.onDocumentUpdated(
  'votaciones/{votacionId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.estado === after.estado) return null;
    if (after.estado !== 'rechazada') return null;
    if (after.tipo !== 'proyecto') return null;

    const proyectoId = after.objetoId;

    try {
      await admin.firestore()
        .collection('proyectos')
        .doc(proyectoId)
        .update({ estado: 'cancelado' });

      console.log(`[VotacionRechazada] Proyecto ${proyectoId} → cancelado`);
    } catch (error) {
      console.error('[VotacionRechazada] Error:', error);
    }
    return null;
  }
);

// ─── HTTP: migrar Custom Claims para usuarios existentes ──────────────────
const { onRequest } = require('firebase-functions/v2/https');

exports.migrarCustomClaims = onRequest(
  { region: 'southamerica-east1' },
  async (req, res) => {
    if (req.query.token !== 'migrar2026cooperadora') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const snap = await admin.firestore().collection('usuarios').get();
    let actualizados = 0;
    let errores = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const uid = data.authUid || doc.id;
      const rol = data.rol || 'consultante';
      try {
        await admin.auth().setCustomUserClaims(uid, { rol });
        console.log(`[MigrarClaims] ${uid} → rol: ${rol}`);
        actualizados++;
      } catch (e) {
        console.error(`[MigrarClaims] ERROR ${uid}: ${e.message}`);
        errores++;
      }
    }

    res.json({ ok: true, actualizados, errores, total: snap.docs.length });
  }
);
