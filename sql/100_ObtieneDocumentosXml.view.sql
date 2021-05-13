--FACTURA ELECTRONICA GP - MEXICO
--Proyectos:		GETTY
--Propósito:		Genera funciones y vistas de FACTURAS para la facturación electrónica en GP - MEXICO
--Referencia:		
--		01/11/11 Versión CFD 1 - 100823 Normativa formal Anexo 20.pdf, 
--		10/02/12 Versión CFD 2.2 - 111230 Normativa Anexo20.doc
--		25/04/12 Versión CFDI 3.2 - 111230 Normativa Anexo20.doc
--		23/10/17 Versión CFDI 3.3 - cfdv33.pdf
--Utilizado por:	Aplicación C# de generación de factura electrónica México
-----------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiInfoAduaneraXML') IS NOT NULL
   DROP FUNCTION dbo.fCfdiInfoAduaneraXML
GO

create function dbo.fCfdiInfoAduaneraXML(@ITEMNMBR char(31), @SOPTYPE smallint, @SOPNUMBE char(21), @LNITMSEQ int, @CMPNTSEQ int)
returns xml 
as
--Propósito. Obtiene info aduanera para conceptos de importación
--Requisito. Se asume que todos los artículos importados usan número de serie o lote y tienen un número de 14 a 15 dígitos.
--			 De otro modo se consideran nacionales.
--			Pueden haber varios lotes o series por artículo
--24/10/17 jcf Creación cfdi 3.3
--03/01/18 jcf Corrige numPedimento
--16/02/18 jcf El pedimento se puede ingresar en los dos primeros atributos del lote o puede ser el número de lote
--03/06/19 jcf Corrige filtro por longitud del código de pedimento cuando viene en los artributos del lote
--
begin
	declare @cncp xml;
	select @cncp = null;

		WITH XMLNAMESPACES ('http://www.sat.gob.mx/cfd/3' as "cfdi")
		select @cncp = (
		   select ad.NumeroPedimento	--, ad.fecha
		   from (
				--En caso de usar número de lote, la info aduanera viene en el número de lote o los atributos del lote
				select top 1 
						case when dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(ltrim(rtrim(la.LOTATRB1)) + ltrim(rtrim(la.LOTATRB2))),10) = '' then
								stuff(stuff(stuff(REPLACE(
													la.LOTNUMBR, ' ', '') 
													, 3, 0, '  '), 7, 0, '  '), 13, 0, '  ')
							else 
								stuff(stuff(stuff(REPLACE(
													dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(ltrim(rtrim(la.LOTATRB1)) + ltrim(rtrim(la.LOTATRB2))),10), 
													' ', '') 
													, 3, 0, '  '), 7, 0, '  '), 13, 0, '  ')
						end NumeroPedimento
				  from SOP10201 sl WITH (NOLOCK) 
					INNER JOIN IV00301 la WITH (NOLOCK) --iv_lot_attributes [ITEMNMBR LOTNUMBR]
					ON sl.ITEMNMBR = la.ITEMNMBR 
					AND sl.SERLTNUM = la.LOTNUMBR
				  inner join IV00101 ma			--iv_itm_mstr
					on ma.ITEMNMBR = la.ITEMNMBR
				 where ma.ITMTRKOP = 3			--lote
					and la.ITEMNMBR = @ITEMNMBR
					and sl.SOPTYPE = @SOPTYPE
					AND sl.SOPNUMBE = @SOPNUMBE
					AND sl.LNITMSEQ = @LNITMSEQ 
					AND sl.CMPNTSEQ = @CMPNTSEQ
					and (
						len(REPLACE(la.LOTNUMBR, ' ', '')) BETWEEN 14 AND 15
						or 
						len(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(ltrim(rtrim(la.LOTATRB1)) + ltrim(rtrim(la.LOTATRB2))),10)) BETWEEN 14 AND 15
						)
					and (
						isnumeric(REPLACE(la.LOTNUMBR, ' ', '')) = 1
						or
						isnumeric(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(ltrim(rtrim(la.LOTATRB1)) + ltrim(rtrim(la.LOTATRB2))),10)) = 1
						)
					and (
						left(la.LOTNUMBR, 2) between '11' and '99' --últimos dos dígitos del año de validación
						or
						left(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(ltrim(rtrim(la.LOTATRB1)) + ltrim(rtrim(la.LOTATRB2))),10), 2) between '11' and '99'
						)

				union all

				--En caso de usar número de serie, la info aduanera viene de los campos def por el usuario de la recepción de compra
				select top 1 stuff(stuff(stuff(replace(dbo.fCfdReemplazaCaracteresNI(rtrim(ud.user_defined_text01)), ' ', '') 
												, 3, 0, '  '), 7, 0, '  '), 13, 0, '  ') NumeroPedimento
				  from POP30330	rs				--POP_SerialLotHist [POPRCTNM RCPTLNNM QTYTYPE SLTSQNUM]
					inner JOIN POP10306 ud		--POP_ReceiptUserDefined 			
						on ud.POPRCTNM = rs.POPRCTNM
					inner join IV00101 ma		--iv_itm_mstr
						on ma.ITEMNMBR = rs.ITEMNMBR
					INNER JOIN SOP10201 sl WITH (NOLOCK) 
						ON sl.ITEMNMBR = rs.ITEMNMBR 
						AND sl.SERLTNUM = rs.SERLTNUM
				where ma.ITMTRKOP = 2			--serie
					and rs.ITEMNMBR = @ITEMNMBR
					and sl.SOPTYPE = @SOPTYPE
					AND sl.SOPNUMBE = @SOPNUMBE
					AND sl.LNITMSEQ = @LNITMSEQ 
					AND sl.CMPNTSEQ = @CMPNTSEQ
					and len(REPLACE(ud.user_defined_text01, ' ', '')) BETWEEN 14 AND 15
					and isnumeric(REPLACE(ud.user_defined_text01, ' ', '')) = 1
					and left(ud.user_defined_text01, 2) between '11' and '99' --últimos dos dígitos del año de validación
				) ad
			FOR XML raw('cfdi:InformacionAduanera') , type
		)
	return @cncp
end
go

IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdiInfoAduaneraXML()'
ELSE PRINT 'Error en la creación de: fCfdiInfoAduaneraXML()'
GO

-------------------------------------------------------------------------------------------------------
IF (OBJECT_ID ('dbo.vwCfdiSopLineasTrxVentas', 'V') IS NULL)
   exec('create view dbo.vwCfdiSopLineasTrxVentas as SELECT 1 as t');
go

-- select dt.soptype, dt.sopnumbe, dt.LNITMSEQ, dt.ITEMNMBR, dt.ShipToName,
-- 	dt.QUANTITY, dt.UOFM,
-- 	case when dt.soptype = 4 then
-- 			pa.param2
-- 		else um.UOFMLONGDESC
-- 	end UOFMsat,
-- 	case when dt.soptype = 4 then
-- 			udmnc.descripcion
-- 		else udmfa.descripcion
-- 	end UOFMsat_descripcion,
-- 	um.UOFMLONGDESC, 
-- 	case when dt.soptype = 4 then
-- 		ISNULL(prod.descripcion, dt.ITEMDESC)
-- 	else
-- 		dt.ITEMDESC
-- 	end ITEMDESC, 
-- 	dt.ORUNTPRC, dt.OXTNDPRC, dt.CMPNTSEQ, 
-- 	dt.QUANTITY * dt.ORUNTPRC importe, 
-- 	isnull(ma.ITMTRKOP, 1) ITMTRKOP,		--3 lote, 2 serie, 1 nada
-- 	case when dt.soptype = 4 then
-- 			pa.param1
-- 		else 
-- 			case when pa.param3 = 'CATEGORIA' 
-- 				then ma.uscatvls_6
-- 				else pa.param3 
-- 			end
-- 	end ClaveProdServ,

alter view dbo.vwCfdiSopLineasTrxVentas as
--Propósito. Obtiene todas las líneas de facturas de venta SOP
--			Incluye descuentos
--Requisito. Atención ! DEBE usar unidades de medida listadas en el SAT. 
--30/11/17 JCF Creación cfdi 3.3
--05/01/18 jcf Agrega parámetro id de exportación, uscatvls_5
--03/07/18 jcf Agrega uscatvls_4
--12/12/19 jcf Agrega descripción del primer item en caso de nc
--02/03/20 jcf NC puede tener más de un ítem en el detalle
--
select dt.soptype, dt.sopnumbe, dt.LNITMSEQ, dt.ITEMNMBR, dt.ShipToName,
	dt.QUANTITY, dt.UOFM,
	um.UOFMLONGDESC 	UOFMsat,
	udmfa.descripcion 	UOFMsat_descripcion,
	um.UOFMLONGDESC, 
	dt.ITEMDESC, 
	dt.ORUNTPRC, dt.OXTNDPRC, dt.CMPNTSEQ, 
	dt.QUANTITY * dt.ORUNTPRC importe, 
	isnull(ma.ITMTRKOP, 1) ITMTRKOP,		--3 lote, 2 serie, 1 nada
	case when pa.param3 = 'CATEGORIA' 
		then ma.uscatvls_6
		else pa.param3 
	end	ClaveProdServ,
	ma.uscatvls_4,
	ma.uscatvls_5, 
	ma.uscatvls_6, 
	dt.ormrkdam,
	dt.QUANTITY * dt.ormrkdam descuento,
	pa.param4 idExporta
from SOP30300 dt
left join iv00101 ma				--iv_itm_mstr
	on ma.ITEMNMBR = dt.ITEMNMBR
outer apply dbo.fCfdUofMSAT(ma.UOMSCHDL, dt.UOFM ) um
outer apply dbo.fcfdiparametros('CLPRODSERV','CLUNIDAD','CLPRODORIGEN','CFDIEXPORTA','NA','NA','PREDETERMINADO') pa
outer apply dbo.fCfdiCatalogoGetDescripcion('UDM', um.UOFMLONGDESC) udmfa
-- outer apply dbo.fCfdiCatalogoGetDescripcion('UDM', pa.param2) udmnc
-- outer apply dbo.fCfdiCatalogoGetDescripcion('PROD', pa.param1) prod

go	

IF (@@Error = 0) PRINT 'Creación exitosa de: vwCfdiSopLineasTrxVentas'
ELSE PRINT 'Error en la creación de: vwCfdiSopLineasTrxVentas'
GO

-------------------------------------------------------------------------------------------------------

IF (OBJECT_ID ('dbo.vwCfdiSopLineasConSerialLot', 'V') IS NULL)
   exec('create view dbo.vwCfdiSopLineasConSerialLot as SELECT 1 as t');
go

alter view dbo.vwCfdiSopLineasConSerialLot as
--Propósito. Obtiene todas las líneas de facturas de venta SOP 
--			También obtiene la serie/lote del artículo o kits
--			Incluye descuentos
--Requisito. Atención ! DEBE usar unidades de medida listadas en el SAT. 
--29/11/17 JCF Creación cfdi 3.3
--05/01/18 jcf Agrega parámetro id de exportación
--
select dt.soptype, dt.sopnumbe, dt.LNITMSEQ, dt.ITEMNMBR, dt.ShipToName,
	ISNULL(sr.serltqty, dt.QUANTITY) cantidad, dt.QUANTITY, sr.serltqty, dt.UOFM, 
	dt.UOFMsat, 
	dt.UOFMsat_descripcion,
	dt.UOFMLONGDESC, 
	sr.SERLTNUM, dt.ITEMDESC, dt.ORUNTPRC, dt.OXTNDPRC, dt.CMPNTSEQ, 
	case when isnull(sr.SOPNUMBE, '_nulo')='_nulo' then 
			dt.QUANTITY * dt.ORUNTPRC
		else 
			sr.SERLTQTY * dt.ORUNTPRC
	end importe,
	isnull(dt.ITMTRKOP, 1) ITMTRKOP,		--3 lote, 2 serie, 1 nada
	dt.ClaveProdServ, 
	dt.uscatvls_6, 
	case when isnull(sr.SOPNUMBE, '_nulo')='_nulo' then 
			dt.QUANTITY * dt.ormrkdam
		else 
			sr.SERLTQTY * dt.ormrkdam
	end descuento,
	dt.idExporta
from vwCfdiSopLineasTrxVentas dt
left join sop10201 sr				--SOP_Serial_Lot_WORK_HIST
	on sr.SOPNUMBE = dt.SOPNUMBE
	and sr.SOPTYPE = dt.SOPTYPE
	and sr.CMPNTSEQ = dt.CMPNTSEQ
	and sr.LNITMSEQ = dt.LNITMSEQ

go	

IF (@@Error = 0) PRINT 'Creación exitosa de: vwCfdiSopLineasConSerialLot'
ELSE PRINT 'Error en la creación de: vwCfdiSopLineasConSerialLot'
GO

-------------------------------------------------------------------------------------------------------

IF OBJECT_ID ('dbo.fCfdiParteXML') IS NOT NULL
   DROP FUNCTION dbo.fCfdiParteXML
GO

create function dbo.fCfdiParteXML(@soptype smallint, @sopnumbe char(21), @LNITMSEQ int, @DOCID char(15))
returns xml 
as
--Propósito. Obtiene info de componentes de kit e info aduanera
--02/05/12 jcf Creación
--03/01/18 jcf Corrige info aduanera
--05/01/18 jcf En caso de complemento de comercio exterior, no debe generar info aduanera
--
begin
	declare @cncp xml;
	WITH XMLNAMESPACES ('http://www.sat.gob.mx/cfd/3' as "cfdi")
	select @cncp = (
		select dt.ClaveProdServ,
				case when dt.ITMTRKOP = 2 then --tracking option: serie
					dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(dt.SERLTNUM))),10) 
					else null
				end NoIdentificacion, 
				dt.cantidad Cantidad, 
				dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(dt.ITEMDESC))), 10) Descripcion,
				case when dt.idExporta = @DOCID 
					then null
					else dbo.fCfdiInfoAduaneraXML(dt.ITEMNMBR, dt.SOPTYPE , dt.SOPNUMBE , dt.LNITMSEQ , dt.CMPNTSEQ )
				end
				--dbo.fCfdiInfoAduaneraSLXML(dt.ITEMNMBR, dt.SERLTNUM)
		from vwCfdiSopLineasConSerialLot dt
		where dt.soptype = @soptype
		and dt.sopnumbe = @sopnumbe
		and dt.LNITMSEQ = @LNITMSEQ
		and dt.CMPNTSEQ <> 0		--a nivel componente de kit
		FOR XML raw('cfdi:Parte') , type
	)
	return @cncp
end
go

IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdiParteXML()'
ELSE PRINT 'Error en la creación de: fCfdiParteXML()'
GO

--------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiCuentaPredial') IS NOT NULL
begin
   DROP FUNCTION dbo.fCfdiCuentaPredial
   print 'función fCfdiCuentaPredial eliminada'
end
GO

create function dbo.fCfdiCuentaPredial(@p_soptype smallint, @p_sopnumbe varchar(21), @p_LNITMSEQ int)
returns table 
--Propósito. Nodo CuentaPredial
--08/05/18 jcf Creación
--
return (
		select
			dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(rtrim(comment_1)+rtrim(comment_2)+rtrim(comment_3)), 10)) Numero
		from sop10202 cmt	--sop_line_cmt_work_hist
 		where cmt.SOPTYPE = @p_soptype
			and cmt.SOPNUMBE = @p_sopnumbe
			and cmt.LNITMSEQ = @p_LNITMSEQ
			and cmt.CMPNTSEQ = 0
		)
go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiCuentaPredial()'
ELSE PRINT 'Error en la creación de la función: fCfdiCuentaPredial()'
GO

--------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiConceptos') IS NOT NULL
   DROP FUNCTION dbo.fCfdiConceptos
GO

create function dbo.fCfdiConceptos(@p_soptype smallint, @p_sopnumbe varchar(21), @p_subtotal numeric(19,6), @p_descuento numeric(19,6))
returns table 
as
--Propósito. Obtiene las líneas de una factura 
--			Elimina carriage returns, line feeds, tabs, secuencias de espacios y caracteres especiales.
--20/11/17 jcf Creación cfdi 3.3
--05/01/18 jcf Agrega idExporta
--05/04/18 jcf Agrega descuento a nc
--09/05/18 jcf Agrega cuenta predial
--04/06/19 jcf Agrega descripción ampliada de int_sopline_data para Getty. Se debe crear la tabla int_sopline_data previamente.
--02/03/20 jcf NC puede tener más de un ítem en el detalle
--
return(
		select Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ, Concepto.ITEMNMBR, --Concepto.SERLTNUM, 
			Concepto.ITEMDESC, Concepto.CMPNTSEQ, Concepto.ShipToName,
			rtrim(Concepto.ClaveProdServ) ClaveProdServ,
			case when @p_soptype = 3 
				then dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(Concepto.ITEMNMBR))),10)  
				else null
			end NoIdentificacion,
			Concepto.quantity			Cantidad, 
			rtrim(Concepto.UOFMsat)		ClaveUnidad, 
			Concepto.UOFMsat_descripcion,
			case when rtrim(isnull(isd.ARTIC_DESC, '')) = '' then
				dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(Concepto.ITEMDESC))), 10) 
			else
				dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(RTRIM(isd.ARTIC_NAME) +' '+ RTRIM(isd.ARTIC_DESC)), 10) 
			end Descripcion, 
			Concepto.ORUNTPRC 		ValorUnitario,
			Concepto.importe  		Importe,
			Concepto.descuento 		Descuento,
			Concepto.idExporta,
			p.param1, cup.Numero cpredial
		from vwCfdiSopLineasTrxVentas Concepto
			left join dbo.INT_SOPLINE_DATA isd
				on isd.sopnumbe = Concepto.sopnumbe
				and isd.LNITMSEQ = Concepto.LNITMSEQ
				and isd.soptype = Concepto.soptype
			outer apply dbo.fCfdiParametros('OBLIGACPREDIAL', 'NA', 'NA', 'NA', 'NA', 'NA', 'PREDETERMINADO') p
			outer apply dbo.fCfdiCuentaPredial(Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ) cup
		where Concepto.CMPNTSEQ = 0					--a nivel kit
		and Concepto.soptype = @p_soptype
		and Concepto.sopnumbe = @p_sopnumbe
)
go
		--and @p_soptype = 3

		--union all

		-- select top (1) Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ, Concepto.ITEMNMBR, --Concepto.SERLTNUM,
		-- 	Concepto.ITEMDESC, Concepto.CMPNTSEQ, '' ShipToName,
		-- 	rtrim(Concepto.ClaveProdServ) ClaveProdServ,
		-- 	null NoIdentificacion,
		-- 	1 Cantidad,
		-- 	rtrim(Concepto.UOFMsat) ClaveUnidad,
		-- 	Concepto.UOFMsat_descripcion,
		-- 	dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(Concepto.ITEMDESC))), 10) Descripcion, 
		-- 	@p_subtotal		ValorUnitario,
		-- 	@p_subtotal		Importe,
		-- 	@p_descuento	Descuento,
		-- 	Concepto.idExporta,
		-- 	p.param1, cup.Numero cpredial
		-- from vwCfdiSopLineasTrxVentas Concepto
		-- 	outer apply dbo.fCfdiParametros('OBLIGACPREDIAL', 'NA', 'NA', 'NA', 'NA', 'NA', 'PREDETERMINADO') p
		-- 	outer apply dbo.fCfdiCuentaPredial(Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ) cup
		-- where Concepto.CMPNTSEQ = 0					--a nivel kit
		-- and Concepto.soptype = @p_soptype
		-- and Concepto.sopnumbe = @p_sopnumbe
		-- and @p_soptype = 4
		-- order by Concepto.LNITMSEQ


IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdiConceptos()'
ELSE PRINT 'Error en la creación de: fCfdiConceptos()'
GO

--------------------------------------------------------------------------------------------------------

IF OBJECT_ID ('dbo.fCfdiConceptosXML') IS NOT NULL
   DROP FUNCTION dbo.fCfdiConceptosXML
GO

create function dbo.fCfdiConceptosXML(@p_soptype smallint, @p_sopnumbe varchar(21), @p_subtotal numeric(19,6), @p_descuento numeric(19,6), @DOCID char(15))
returns xml 
as
--Propósito. Obtiene las líneas de una factura en formato xml para CFDI
--			Elimina carriage returns, line feeds, tabs, secuencias de espacios y caracteres especiales.
--23/10/17 jcf Creación cfdi 3.3
--03/01/18 jcf Corrige infor aduanera
--05/01/18 jcf No debe generar info aduanera cuando es exportación
--15/01/18 jcf No debe generar descuento = 0
--05/04/18 jcf Agrega descuento a nc
--09/05/18 jcf Agrega cuenta predial
--27/07/18 jcf Agrega UOFMsat_descripcion
--18/12/19 jcf Modifica llamada a nueva función que obtiene impuestos
--02/03/20 jcf NC puede tener más de un ítem en el detalle
--
begin
	declare @cncp xml;
	if @p_soptype = 4 
	begin
		WITH XMLNAMESPACES ('http://www.sat.gob.mx/cfd/3' as "cfdi")
		select @cncp = (
			select ClaveProdServ				'@ClaveProdServ',
				Cantidad						'@Cantidad',
				ClaveUnidad						'@ClaveUnidad',
				UOFMsat_descripcion				'@Unidad',
				Descripcion						'@Descripcion', 
				cast(ValorUnitario as numeric(19,2)) '@ValorUnitario',
				cast(Importe as numeric(19,2))	'@Importe',
				case when Descuento = 0 then null
					else cast(Descuento as numeric(19, 2))
				end								'@Descuento',
				dbo.fCfdiNodoImpuestosXML(Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ, 1),
				-- dbo.fCfdiNodoImpuestosXML(Concepto.soptype, Concepto.sopnumbe, 0, 1),
				case when upper(isnull(Concepto.param1, 'NO')) = 'SI' 
					then rtrim(Concepto.cpredial)
					else null
				end 'cfdi:CuentaPredial/@Numero'
			from dbo.fCfdiConceptos(@p_soptype, @p_sopnumbe, @p_subtotal, @p_descuento) Concepto
			where Concepto.importe != 0
			FOR XML path('cfdi:Concepto'), type, root('cfdi:Conceptos')
			)
	end
	else 
	begin
		WITH XMLNAMESPACES ('http://www.sat.gob.mx/cfd/3' as "cfdi")
		select @cncp = (
			select 
				ClaveProdServ							'@ClaveProdServ',
				NoIdentificacion						'@NoIdentificacion',
				Cantidad								'@Cantidad', 
				ClaveUnidad								'@ClaveUnidad', 
				UOFMsat_descripcion						'@Unidad',
				Descripcion								'@Descripcion', 
				cast(ValorUnitario as numeric(19, 2))	'@ValorUnitario',
				cast(Importe as numeric(19,2))			'@Importe',
				case when Descuento = 0 then null
					else cast(Descuento as numeric(19, 2))		
				end										'@Descuento',

				dbo.fCfdiNodoImpuestosXML(Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ, 1),

				case when Concepto.idExporta = @DOCID 
					then null
					else dbo.fCfdiInfoAduaneraXML(Concepto.ITEMNMBR, Concepto.SOPTYPE , Concepto.SOPNUMBE , Concepto.LNITMSEQ , Concepto.CMPNTSEQ )
			    end,
				case when upper(isnull(Concepto.param1, 'NO')) = 'SI' 
					then Concepto.cpredial
					else null
				end 'cfdi:CuentaPredial/@Numero',

				dbo.fCfdiParteXML(Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ, @DOCID) 
			from dbo.fCfdiConceptos(@p_soptype, @p_sopnumbe, 0, 0) Concepto
			where Concepto.importe != 0          
			FOR XML path('cfdi:Concepto'), type, root('cfdi:Conceptos')
		)
	end
	return @cncp
end
go

IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdiConceptosXML()'
ELSE PRINT 'Error en la creación de: fCfdiConceptosXML()'
GO

--------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdCertificadoVigente') IS NOT NULL
   DROP FUNCTION dbo.fCfdCertificadoVigente
GO

create function dbo.fCfdCertificadoVigente(@fecha datetime)
returns table
as
--Propósito. Verifica que la fecha corresponde a un certificado vigente y activo
--			Si existe más de uno o ninguno, devuelve el estado: inconsistente
--			También devuelve datos del folio y certificado asociado.
--Requisitos. Los estados posibles para generar o no archivos xml son: no emitido, inconsistente
--24/04/12 jcf Creación cfdi
--23/05/12 jcf El id: PAC está reservado para los certificados del PAC
--15/05/20 jcf Agrega mensaje cuando csd está próximo a caducar
--
return
(  
	select top 1 
			fyc.ID_Certificado, fyc.ruta_certificado, fyc.ruta_clave, fyc.contrasenia_clave, fyc.fila, 
			case when fyc.fila > 1 then 'inconsistente' else 'no emitido' end estado, 
			case when DATEDIFF(day, getdate(), fyc.fecha_vig_hasta) < 7
					then 'CSD caduca en ' + convert(varchar(5), DATEDIFF(day, getdate(), fyc.fecha_vig_hasta)) + ' días. ' 
					else '' 
			end msjCaducaEn
	from (
		SELECT top 2 rtrim(B.ID_Certificado) ID_Certificado, rtrim(B.ruta_certificado) ruta_certificado, rtrim(B.ruta_clave) ruta_clave, 
				rtrim(B.contrasenia_clave) contrasenia_clave, row_number() over (order by B.ID_Certificado) fila,
				B.fecha_vig_desde, B.fecha_vig_hasta
		FROM cfd_CER00100 B
		WHERE B.estado = '1'
			and B.id_certificado <> 'PAC'	--El id PAC está reservado para el PAC
			and datediff(day, B.fecha_vig_desde, @fecha) >= 0
			and datediff(day, B.fecha_vig_hasta, @fecha) <= 0
		) fyc
	order by fyc.fila desc
)
go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdCertificadoVigente()'
ELSE PRINT 'Error en la creación de la función: fCfdCertificadoVigente()'
GO

--------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdCertificadoPAC') IS NOT NULL
   DROP FUNCTION dbo.fCfdCertificadoPAC
GO

create function dbo.fCfdCertificadoPAC(@fecha datetime)
returns table
as
--Propósito. Obtiene el certificado del PAC. 
--			Verifica que la fecha corresponde a un certificado vigente y activo
--Requisitos. El id PAC está reservado para registrar el certificado del PAC. 
--23/5/12 jcf Creación
--
return
(  
	--declare @fecha datetime
	--select @fecha = '5/4/12'
	SELECT rtrim(B.ID_Certificado) ID_Certificado, rtrim(B.ruta_certificado) ruta_certificado, rtrim(B.ruta_clave) ruta_clave, 
			rtrim(B.contrasenia_clave) contrasenia_clave
	FROM cfd_CER00100 B
	WHERE B.estado = '1'
		and B.id_certificado = 'PAC'	--El id PAC está reservado para el PAC
		and datediff(day, B.fecha_vig_desde, @fecha) >= 0
		and datediff(day, B.fecha_vig_hasta, @fecha) <= 0
)
go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdCertificadoPAC()'
ELSE PRINT 'Error en la creación de la función: fCfdCertificadoPAC()'
GO

--------------------------------------------------------------------------------------------------------
--COMPLEMENTO DE COMERCIO EXTERIOR
--------------------------------------------------------------------------------------------------------
IF (OBJECT_ID ('dbo.vwCfdiComercioExteriorMercancias', 'V') IS NULL)
   exec('create view dbo.vwCfdiComercioExteriorMercancias as SELECT 1 as t');
go

alter view dbo.vwCfdiComercioExteriorMercancias
as
--Propósito. Obtiene las líneas de una factura de comercio exterior
--11/01/18 jcf Creación cfdi 3.3
--03/07/18 jcf Agrega uscatvls_4
--
		select Concepto.soptype, Concepto.sopnumbe,
			dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(Concepto.ITEMNMBR))),10) itemnmbr,
			Concepto.uscatvls_5, 
			sum(Concepto.quantity) sumQuantity,
			Concepto.uscatvls_4, --pa.param1,
			sum(Concepto.importe)/sum(Concepto.quantity) sumValorUnitario,
			sum(Concepto.importe) sumImporte
		from dbo.vwCfdiSopLineasTrxVentas Concepto
			outer apply dbo.fcfdiparametros('COEXUM'+RTRIM(Concepto.UOFM),'na','na','na','NA','NA','PREDETERMINADO') pa
		where Concepto.CMPNTSEQ = 0					--a nivel kit
		AND Concepto.importe != 0  
		group by Concepto.soptype, Concepto.sopnumbe, Concepto.itemnmbr, Concepto.uscatvls_5, Concepto.uscatvls_4
go

IF (@@Error = 0) PRINT 'Creación exitosa de: vwCfdiComercioExteriorMercancias()'
ELSE PRINT 'Error en la creación de: vwCfdiComercioExteriorMercancias()'
GO

--------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiComercioExteriorMercanciasXML') IS NOT NULL
   DROP FUNCTION dbo.fCfdiComercioExteriorMercanciasXML
GO

create function dbo.fCfdiComercioExteriorMercanciasXML(@p_soptype smallint, @p_sopnumbe varchar(21))
returns xml 
as
--Propósito. Obtiene las líneas de una factura en formato xml para complemento de comercio exterior
--11/01/18 jcf Creación cfdi 3.3
--02/02/18 jcf No incluir fracción arancelaria si está en blanco
--03/07/18 jcf Agrega uscatvls_4
--
begin
	declare @cncp xml;
		WITH XMLNAMESPACES (
							'http://www.sat.gob.mx/ComercioExterior11' as "cce11")
		select @cncp = (
			select itemnmbr		'@NoIdentificacion',
				CASE WHEN isnull(uscatvls_5, '') = '' then null
					else rtrim(uscatvls_5)		
				end										'@FraccionArancelaria', 
				cast(sumQuantity as numeric(19,3))		'@CantidadAduana',
				rtrim(uscatvls_4)						'@UnidadAduana',
				cast(sumValorUnitario as numeric(19,2)) '@ValorUnitarioAduana',
				cast(sumImporte as numeric(19,2))  		'@ValorDolares'
			from dbo.vwCfdiComercioExteriorMercancias
			where 
			soptype = @p_soptype
			and sopnumbe = @p_sopnumbe
			FOR XML path('cce11:Mercancia'), type, root('cce11:Mercancias')
		)
	return @cncp
end
go

IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdiComercioExteriorMercanciasXML()'
ELSE PRINT 'Error en la creación de: fCfdiComercioExteriorMercanciasXML()'
GO

--------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiGeneraComplemComercioExteriorXML') IS NOT NULL
   DROP FUNCTION dbo.fCfdiGeneraComplemComercioExteriorXML
GO

create function dbo.fCfdiGeneraComplemComercioExteriorXML (@soptype smallint, @sopnumbe varchar(21))
returns xml 
as
--Propósito. Genera el complemento de comercio exterior
--Requisitos. 
--05/01/18 jcf Creación Nodo comercio exterior v1.1
--
begin
	declare @cfd xml;
	WITH XMLNAMESPACES
	(
				'http://www.sat.gob.mx/ComercioExterior11' as "cce11"
	)
	select @cfd = 
	(
	select 
		'1.1'				'@Version',
		2					'@TipoOperacion',
		'A1'				'@ClaveDePedimento',
		case when pais.param1 like 'no existe tag%' then '0' 
			else '1'
		end					'@CertificadoOrigen',
		case when pais.param1 like 'no existe tag%' then null 
			else rtrim(pais.param1)
		end					'@NumCertificadoOrigen',
		case when pais.param2 like 'no existe tag%' then null 
			else rtrim(pais.param2)
		end					'@NumeroExportadorConfiable',
		rtrim(pc.param2) 	'@Incoterm',
		0					'@Subdivision',
		dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(RTRIM(substring(txt.cmmttext, 1, 300))), 10) '@Observaciones', 
		cast(tv.xchgrate as numeric(19,6))	'@TipoCambioUSD',
		cast(tv.total  as numeric(19, 2))	'@TotalUSD',
		--emi.rfc								'cfdi:Emisor/@Curp',	--sólo en caso que el emisor sea persona física
		emi.calle			'cce11:Emisor/cce11:Domicilio/@Calle',
		case when pdir.param1 like 'no existe tag%' then null 
			else rtrim(pdir.param1)
		end					'cce11:Emisor/cce11:Domicilio/@Colonia',
		case when pdir.param2 like 'no existe tag%' then null 
			else rtrim(pdir.param2)
		end					'cce11:Emisor/cce11:Domicilio/@Localidad',
		case when pdir.param3 like 'no existe tag%' then null 
			else rtrim(pdir.param3)
		end					'cce11:Emisor/cce11:Domicilio/@Referencia',
		case when pdir.param4 like 'no existe tag%' then null 
			else rtrim(pdir.param4)
		end					'cce11:Emisor/cce11:Domicilio/@Municipio',
		case when pdir.param5 like 'no existe tag%' then null 
			else rtrim(pdir.param5)
		end					'cce11:Emisor/cce11:Domicilio/@Estado',
		'MEX'				'cce11:Emisor/cce11:Domicilio/@Pais',
		emi.codigoPostal	'cce11:Emisor/cce11:Domicilio/@CodigoPostal',

		rtrim(tv.address1)									'cce11:Receptor/cce11:Domicilio/@Calle',
		case when patindex('%#%', tv.address1) = 0 then null
			else right(rtrim(tv.address1), len(tv.address1)-patindex('%#%', tv.address1)) 
		end													'cce11:Receptor/cce11:Domicilio/@NumeroExterior',
		case when tv.address2= '' then null else tv.address2 end 'cce11:Receptor/cce11:Domicilio/@Colonia',
		case when tv.city = '' then null else tv.city end	'cce11:Receptor/cce11:Domicilio/@Localidad',
		case when tv.address3 = '' then null else tv.address3 end 'cce11:Receptor/cce11:Domicilio/@Municipio',
		tv.[state]											'cce11:Receptor/cce11:Domicilio/@Estado',
		rtrim(tv.ccode)										'cce11:Receptor/cce11:Domicilio/@Pais',
		tv.zipcode											'cce11:Receptor/cce11:Domicilio/@CodigoPostal',

		dbo.fCfdiComercioExteriorMercanciasXML(tv.soptype, tv.sopnumbe)
		
	from dbo.vwCfdiSopTransaccionesVenta tv
		cross join dbo.fCfdEmisor() emi
		left join sop10106 txt
			on txt.sopnumbe = tv.sopnumbe
			and txt.soptype = tv.soptype
			and rtrim(txt.comment_1) != ''
		outer apply dbo.fCfdiParametros('EMICOLONIA', 'EMILOCALIDAD', 'EMIREFERENCIA', 'EMIMUNICIPIO', 'EMIESTADO', 'NA', 'PREDETERMINADO') pdir
		outer apply dbo.fCfdiParametrosCliente(tv.CUSTNMBR, 'UsoCFDI', 'Incoterm', 'na', 'na', 'na', 'na', 'PREDETERMINADO') pc
		outer apply dbo.fCfdiComercioExteriorParametrosPais(tv.CCode, 'NumCertificadoOrigen', 'NumeroExportadorConfiable') pais
	where tv.sopnumbe =	@sopnumbe		
	and tv.soptype = @soptype
	FOR XML path('cce11:ComercioExterior'), type	--, root('cfdi:Complemento')
	)
	return @cfd;
end
go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiGeneraComplemComercioExteriorXML ()'
ELSE PRINT 'Error en la creación de la función: fCfdiGeneraComplemComercioExteriorXML ()'
GO
-----------------------------------------------------------------------------------------

IF OBJECT_ID ('dbo.fCfdiGeneraDocumentoVentaComercioExteriorXML') IS NOT NULL
   DROP FUNCTION dbo.fCfdiGeneraDocumentoVentaComercioExteriorXML
GO

create function dbo.fCfdiGeneraDocumentoVentaComercioExteriorXML (@soptype smallint, @sopnumbe varchar(21))
returns xml 
as
--Propósito. Elabora un comprobante xml para factura electrónica cfdi
--Requisitos. El total de impuestos de la factura debe corresponder a la suma del detalle de impuestos. 
--15/01/18 jcf Creación Complemento de comercio exterior para cfdi 3.3
--05/04/18 jcf Agrega descuento a nc
--16/11/18 jcf Agrega usrtab09, ctrl.usrtab03. Tercera resolución de modificaciones 2.7.1.44 SAT
--
begin
	declare @cfd xml;
	WITH XMLNAMESPACES
	(
				'http://www.w3.org/2001/XMLSchema-instance' as "xsi",
				'http://www.sat.gob.mx/cfd/3' as "cfdi",
				'http://www.sat.gob.mx/ComercioExterior11' as "cce11"
	)

	select @cfd = 
	(
	select 
		'http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv33.xsd http://www.sat.gob.mx/ComercioExterior11 http://www.sat.gob.mx/sitio_internet/cfd/ComercioExterior11/ComercioExterior11.xsd' '@xsi:schemaLocation',
		emi.[version]										'@Version',
		rtrim(tv.docid)										'@Serie',
		rtrim(tv.sopnumbe)									'@Folio',
		convert(datetime, tv.fechahora, 126)				'@Fecha',
		''													'@Sello', 

		--case when tv.soptype = 3 
		--	then case when tv.orpmtrvd = tv.total 
		--			then pg.FormaPago
		--			else '99'
		--		end
		--	else tr.FormaPago
		--end													
		mtp.formaPago										'@FormaPago',
		''													'@NoCertificado', 
		''													'@Certificado', 
		case when tv.pymtrmid='' then null 
			else rtrim(tv.pymtrmid) 
		end													'@CondicionesDePago',

		cast(tv.subtotal as numeric(19,2))					'@SubTotal',
		case when tv.descuento = 0 then null 
			else cast(tv.descuento as numeric(19,2)) 
		end													'@Descuento',
		tv.curncyid											'@Moneda',

		case when tv.curncyid in ('MXN', 'XXX')
			then null
			else cast(tv.xchgrate as numeric(19,6))
		end													'@TipoCambio',

		cast(tv.total  as numeric(19, 2))					'@Total',
		case when tv.SOPTYPE = 3 
			then 'I' 
			else 'E' 
		end													'@TipoDeComprobante',

		--case when tv.soptype = 3
		--	then case when tv.orpmtrvd = tv.total
		--		then 'PUE'
		--		Else 'PPD'
		--		END
		--	else case when tr.FormaPago = '99'
		--		then 'PPD'
		--		Else 'PUE'
		--		END
		--end													
		mtp.metodoPago										'@MetodoPago',
		emi.codigoPostal									'@LugarExpedicion',

        tr.TipoRelacion										'cfdi:CfdiRelacionados/@TipoRelacion',
		dbo.fCfdiRelacionadosXML(tv.soptype, tv.sopnumbe, tv.docid, tr.TipoRelacion) 'cfdi:CfdiRelacionados',
				
		emi.rfc												'cfdi:Emisor/@Rfc',
		emi.nombre											'cfdi:Emisor/@Nombre', 
		emi.regimen											'cfdi:Emisor/@RegimenFiscal',

		tv.idImpuestoCliente								'cfdi:Receptor/@Rfc',
		tv.nombreCliente									'cfdi:Receptor/@Nombre', 

		case when tv.idImpuestoCliente = 'XEXX010101000'
			then rtrim(tv.ccode)
			else null
		end													'cfdi:Receptor/@ResidenciaFiscal', 
		case when tv.idImpuestoCliente = 'XEXX010101000'
			then rtrim(tv.taxexmt1)
			else null
		end													'cfdi:Receptor/@NumRegIdTrib', 

		case when tv.idImpuestoCliente != 'XEXX010101000'
			then case when tv.usrtab01 = '' then isnull(pc.param1, 'P01') else left(upper(tv.usrtab01), 3) end
			else 'P01'
		END													'cfdi:Receptor/@UsoCFDI',

		dbo.fCfdiConceptosXML(tv.soptype, tv.sopnumbe, tv.subtotal, tv.descuento, tv.docid),
		
		cast(tv.impuesto as numeric(19,2))					'cfdi:Impuestos/@TotalImpuestosTrasladados',		
		dbo.fCfdiImpuestosTrasladadosXML(tv.soptype, tv.sopnumbe, 0, 0)	'cfdi:Impuestos',

		dbo.fCfdiGeneraComplemComercioExteriorXML (tv.soptype, tv.sopnumbe) 'cfdi:Complemento'
	from dbo.vwCfdiSopTransaccionesVenta tv
		cross join dbo.fCfdEmisor() emi
		outer apply dbo.fCfdiPagoSimultaneoMayor(tv.soptype, tv.sopnumbe) pg
		outer apply dbo.fCfdiDatosDeUnaRelacion(tv.soptype, tv.sopnumbe, tv.docid) tr
		outer apply dbo.fCfdiParametrosCliente(tv.CUSTNMBR, 'UsoCFDI', 'na', 'na', 'na', 'na', 'na', 'PREDETERMINADO') pc
		outer apply dbo.fCfdiMetodoYFormaPago(tv.soptype, tv.orpmtrvd, tv.total, left(upper(tv.usrtab09), 3), tr.FormaPago, pg.FormaPago, left(upper(tv.usrtab03), 2)) mtp
	where tv.sopnumbe =	@sopnumbe		
	and tv.soptype = @soptype
	FOR XML path('cfdi:Comprobante'), type
	)
	return @cfd;
end
go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiGeneraDocumentoVentaComercioExteriorXML ()'
ELSE PRINT 'Error en la creación de la función: fCfdiGeneraDocumentoVentaComercioExteriorXML ()'
GO

-----------------------------------------------------------------------------------------
--COMPROBANTE STANDARD
-----------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiGeneraDocumentoDeVentaXML') IS NOT NULL
   DROP FUNCTION dbo.fCfdiGeneraDocumentoDeVentaXML
GO

create function dbo.fCfdiGeneraDocumentoDeVentaXML (@soptype smallint, @sopnumbe varchar(21))
returns xml 
as
--Propósito. Elabora un comprobante xml para factura electrónica cfdi
--Requisitos. El total de impuestos de la factura debe corresponder a la suma del detalle de impuestos. 
--			Se asume que No incluye retenciones
--23/10/17 jcf Creación cfdi 3.3
--12/12/17 jcf No debe mostrar descuento si no hay descuento en el detalle
--16/01/18 jcf No incluir CondicionesDePago si está vacío
--05/04/18 jcf Agrega descuento a nc
--16/11/18 jcf Agrega usrtab09, ctrl.usrtab03. Tercera resolución de modificaciones 2.7.1.44 SAT
--18/12/19 jcf Modifica llamada a nueva función que obtiene impuestos
--
begin
	declare @cfd xml;
	WITH XMLNAMESPACES
	(
				'http://www.w3.org/2001/XMLSchema-instance' as "xsi",
				'http://www.sat.gob.mx/cfd/3' as "cfdi"
	)
	select @cfd = 
	(
	select 
		'http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv33.xsd'	'@xsi:schemaLocation',
		emi.[version]										'@Version',
		rtrim(tv.docid)										'@Serie',
		rtrim(tv.sopnumbe)									'@Folio',
		convert(datetime, tv.fechahora, 126)				'@Fecha',
		''													'@Sello', 
		mtp.formaPago										'@FormaPago',
		''													'@NoCertificado', 
		''													'@Certificado', 
		case when tv.pymtrmid='' then null 
			else rtrim(tv.pymtrmid) 
		end													'@CondicionesDePago',

		cast(tv.subtotal as numeric(19,2))					'@SubTotal',
		case when tv.descuento = 0 then null 
			else cast(tv.descuento as numeric(19,2)) 
		end													'@Descuento',
		tv.curncyid											'@Moneda',

		case when tv.curncyid in ('MXN', 'XXX')
			then null
			else cast(tv.xchgrate as numeric(19,6))
		end													'@TipoCambio',

		cast(tv.total  as numeric(19, 2))					'@Total',
		case when tv.SOPTYPE = 3 
			then 'I' 
			else 'E' 
		end													'@TipoDeComprobante',

		mtp.metodoPago										'@MetodoPago',
		emi.codigoPostal									'@LugarExpedicion',

        tr.TipoRelacion										'cfdi:CfdiRelacionados/@TipoRelacion',
		dbo.fCfdiRelacionadosXML(tv.soptype, tv.sopnumbe, tv.docid, tr.TipoRelacion) 'cfdi:CfdiRelacionados',
				
		emi.rfc												'cfdi:Emisor/@Rfc',
		emi.nombre											'cfdi:Emisor/@Nombre', 
		emi.regimen											'cfdi:Emisor/@RegimenFiscal',

		tv.idImpuestoCliente								'cfdi:Receptor/@Rfc',
		tv.nombreCliente									'cfdi:Receptor/@Nombre', 

		case when tv.idImpuestoCliente = 'XEXX010101000'
			then rtrim(tv.ccode)
			else null
		end													'cfdi:Receptor/@ResidenciaFiscal', 
		case when tv.idImpuestoCliente = 'XEXX010101000'
			then rtrim(tv.taxexmt1)
			else null
		end													'cfdi:Receptor/@NumRegIdTrib', 

		case when tv.idImpuestoCliente != 'XEXX010101000'
			then case when tv.usrtab01 = '' then isnull(pc.param1, 'P01') else left(upper(tv.usrtab01), 3) end
			else 'P01'
		END													'cfdi:Receptor/@UsoCFDI',

		dbo.fCfdiConceptosXML(tv.soptype, tv.sopnumbe, tv.subtotal, tv.descuento, tv.docid),
		
		dbo.fCfdiNodoImpuestosXML(tv.soptype, tv.sopnumbe, 0, 0),

		''													'cfdi:Complemento'
	from dbo.vwCfdiSopTransaccionesVenta tv
		cross join dbo.fCfdEmisor() emi
		outer apply dbo.fCfdiDatosDeUnaRelacion(tv.soptype, tv.sopnumbe, tv.docid) tr
		outer apply dbo.fCfdiPagoSimultaneoMayor(tv.soptype, tv.sopnumbe) pg
		outer apply dbo.fCfdiParametrosCliente(tv.CUSTNMBR, 'UsoCFDI', 'na', 'na', 'na', 'na', 'na', 'PREDETERMINADO') pc
		outer apply dbo.fCfdiMetodoYFormaPago(tv.soptype, tv.orpmtrvd, tv.total, left(upper(tv.usrtab09), 3), tr.FormaPago, pg.FormaPago, left(upper(tv.usrtab03), 2)) mtp
 	where tv.sopnumbe =	@sopnumbe		
	and tv.soptype = @soptype
	FOR XML path('cfdi:Comprobante'), type
	)
	return @cfd;
end
go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiGeneraDocumentoDeVentaXML ()'
ELSE PRINT 'Error en la creación de la función: fCfdiGeneraDocumentoDeVentaXML ()'
GO

