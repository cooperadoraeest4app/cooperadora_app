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
