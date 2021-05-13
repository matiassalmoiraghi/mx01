using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;
using System.Xml;
using System.Xml.Xsl;

using Comun;
using EjecutableEncriptador;
using Encriptador;
using MaquinaDeEstados;

namespace cfd.FacturaElectronica
{
    class cfdFacturaXmlWorker : BackgroundWorker
    {
        private Parametros _Param;
        private ConexionAFuenteDatos _Conex;
        public string ultimoMensaje = "";
       

        public cfdFacturaXmlWorker(ConexionAFuenteDatos Conex, Parametros Param)
        {
            WorkerReportsProgress = true;
            WorkerSupportsCancellation = true;
            _Param = Param;
            _Conex = Conex;
        }

        /// <summary>
        /// Ejecuta la generación de archivos xml y pdf en un thread independiente
        /// </summary>
        /// <param name="e">trxVentas</param>
        protected override void OnDoWork(DoWorkEventArgs e)
        {
            try
            {
                String msj=String.Empty;
                String msj_pac = String.Empty;
                ReportProgress(0, "Revisando configuración...\r\n");
                object[] args = e.Argument as object[];
                vwCfdTransaccionesDeVenta trxVenta = (vwCfdTransaccionesDeVenta)args[0];
                trxVenta.Rewind();                                                          //move to first record

                int errores = 0; int i = 1;
                string antiguoIdCertificado = "";
                XmlDocument sello = new XmlDocument();
                TecnicaDeEncriptacion criptografo = null;
                XmlDocument comprobante = new XmlDocument();
                XmlDocumentFragment addenda;
                cfdReglasFacturaXml DocVenta = new cfdReglasFacturaXml(_Conex, _Param);     //log de facturas xml emitidas y anuladas
                ReglasME maquina = new ReglasME(_Param);
                ValidadorXML validadorxml = new ValidadorXML(_Param);
                TransformerXML loader = new TransformerXML(_Param);
                ReportProgress(0, "Ruta Certificado PFX PAC: " + trxVenta.Ruta_clavePac + " Contraseña PAC " + trxVenta.Contrasenia_clavePac + "\r\n");
                ReportProgress(0, "Ruta Certificado PAC: " + trxVenta.Ruta_certificadoPac + "\r\n");

                PAC representanteSat = new PAC(trxVenta.Ruta_certificadoPac, trxVenta.Ruta_clavePac, trxVenta.Contrasenia_clavePac, _Param, out msj_pac);
                String Sello = string.Empty;
                ReportProgress(0, "." + msj_pac + "\r\n");



                ReportProgress(0, "Iniciando proceso...\r\n");
               
                do
                {
                    _Param.PrefijoDefaultFactura = trxVenta.Sopnumbe.Substring(_Param.PosicionPrefijoFactura, 1);
                    msj = String.Empty;
                    try
                    {
                        if (CancellationPending) { e.Cancel = true; return; }

                        if (trxVenta.Estado.Equals("no emitido") &&
                            maquina.ValidaTransicion(_Param.tipoDoc, "EMITE XML Y PDF", trxVenta.EstadoActual, "emitido/impreso"))
                            if (trxVenta.Voidstts == 0)  //documento no anulado
                            {
                                //Cargar los datos del certificado por cada nuevo Id de certificado asociado al documento de venta
                                if (!trxVenta.ID_Certificado.Equals(antiguoIdCertificado))
                                {
                                    criptografo = new TecnicaDeEncriptacion(trxVenta.Ruta_clave, trxVenta.Contrasenia_clave, trxVenta.Ruta_certificado.Trim(), trxVenta.Ruta_certificado.Replace(".cer", ".pem").Trim());
                                    antiguoIdCertificado = trxVenta.ID_Certificado;
                                }

                                comprobante.LoadXml(trxVenta.ComprobanteXml);
                                comprobante.DocumentElement.SetAttribute("NoCertificado", criptografo.noCertificado);

                                loader.getCadenaOriginal(comprobante);                  //Obtener cadena original del CFD

                                Sello = criptografo.obtieneSello(loader.cadenaOriginal);//Crear el archivo xml y sellarlo
                                comprobante.DocumentElement.SetAttribute("Sello", Sello);
                                comprobante.DocumentElement.SetAttribute("Certificado", criptografo.certificadoFormatoPem);

                                if (!_Conex.IntegratedSecurity)                         //para testeo:
                                    comprobante.Save(new XmlTextWriter(trxVenta.Sopnumbe.Trim() + "tst.xml", Encoding.UTF8));

                                validadorxml.ValidarXSD(comprobante);                   //Validar el esquema del archivo xml

                                representanteSat.comprobanteFiscal = comprobante;
                                representanteSat.timbraCFD();                           //agregar sello al comprobante

                                //Agregar el nodo addenda si existe
                                if (trxVenta.Addenda != null && trxVenta.Addenda.Length > 0)
                                {
                                    addenda = comprobante.CreateDocumentFragment();
                                    addenda.InnerXml = trxVenta.Addenda;
                                    comprobante.DocumentElement.AppendChild(addenda);
                                }

                                //Guarda el archivo xml, genera el cbb y el pdf. 
                                //Luego anota en la bitácora la factura emitida o el error al generar cbb o pdf.
                                DocVenta.AlmacenaEnRepositorio(trxVenta, comprobante, maquina, representanteSat.Uuid, Sello);

                                //CodigoDeBarras cbb = new CodigoDeBarras();
                                //cbb.GenerarQRBidimensional(_Param.URLConsulta + "?&id=AABBCCDDEEFFGGHHIIOOPPQQRRSSTTUU&re=" + trxVenta.Rfc + "&rr=" + trxVenta.IdImpuestoCliente.Trim() + "&tt=" + trxVenta.Total.ToString() + "&fe=QWERTYU8"
                                //                        , trxVenta.RutaXml.Trim() + "cbb\\cbbtest.jpg");

                            }
                            else //si el documento está anulado en gp, agregar al log como emitido
                            {
                                maquina.ValidaTransicion("FACTURA", "ANULA VENTA", trxVenta.EstadoActual, "emitido");
                                msj = "Anulado en GP y marcado como emitido.";
                                DocVenta.RegistraLogDeArchivoXML(trxVenta.Soptype, trxVenta.Sopnumbe, "Anulado en GP", "0", _Conex.Usuario, "",
                                                                         "emitido", maquina.eBinarioNuevo, msj.Trim());
                            }
                    }
                    catch (Exception lo)
                    {
                        string imsj = lo.InnerException == null ? "" : lo.InnerException.ToString();
                        msj = lo.Message + " " + imsj + Environment.NewLine + comprobante.InnerXml; //lo.StackTrace;
                        errores++;
                    }
                    finally
                    {
                        ReportProgress(i * 100 / trxVenta.RowCount, "Doc:" + trxVenta.Sopnumbe + " " + msj.Trim() + Environment.NewLine);
                        i++;
                    }
                } while (trxVenta.MoveNext() && errores < 10);
            }
            catch (Exception xw)
            {
                string imsj = xw.InnerException == null ? "" : xw.InnerException.ToString();
                this.ultimoMensaje = xw.Message + " " + imsj + "\r\n" + xw.StackTrace;
            }
            finally
            {
                ReportProgress(100, ultimoMensaje);
            }
            e.Result = "Proceso finalizado! \r\n ";
            ReportProgress(100, "");
        }

    }
}
