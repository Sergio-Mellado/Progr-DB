-- DECLARACIÓN DE VARIABLES BIND
VAR b_mes NUMBER
VAR b_annio NUMBER
VAR b_valor_limite NUMBER
EXEC :b_mes := &mes
EXEC :b_annio := &annio
EXEC :b_valor_limite := 50000
VAR b_usuario NVARCHAR2(20)
EXEC : b_usuario:= 'smellado'
DECLARE
-- DECLARACIÓN DE VARIABLES ESCALARES
v_num_pedidos NUMBER;
v_monto_pedidos NUMBER;
v_monto_gravamen NUMBER;
v_pct_gravamen NUMBER;
v_mensaje_oracle VARCHAR2(250);
v_total_monto_gravamen NUMBER;
v_descuento_cepa NUMBER;
v_monto_delivery NUMBER;
v_monto_descuentos NUMBER;
v_recaudacion NUMBER;
limite_descuento EXCEPTION;
v_total_decuento_cepa NUMBER;
v_mensaje_oracle2 VARCHAR2(250);
v_nuevo_descuento NUMBER;
v_desct_limite NUMBER;
v_desct_cepa VARCHAR2(250);
b_usuario VARCHAR2(20) := 'smellado' ;


--CURSOR SIN¨PARAMETRO CEPA
CURSOR cur_cepa IS
    SELECT nom_cepa
    FROM cepa
    ORDER BY nom_cepa;

--CURSOR CON¨PARAMETRO RESUMEN_VENTAS_CEPAS
CURSOR cur_resumen_ventas_cepas(p_nom_cepa VARCHAR2) IS
SELECT
    ce.nom_cepa,
    dp.id_pedido,
    dp.subtotal,
    p.id_cepa,
    pdt.fec_pedido
FROM cepa CE  JOIN producto P
        ON ce.id_cepa=p.id_cepa
         JOIN detalle_pedido DP
        ON p.id_producto=dp.id_producto
         JOIN pedido PDT
        ON dp.id_pedido=pdt.id_pedido
        WHERE ce.nom_cepa=p_nom_cepa 
        AND EXTRACT(MONTH FROM pdt.fec_pedido) = :b_mes AND EXTRACT(YEAR FROM pdt.fec_pedido) = :b_annio
        ORDER BY ce.nom_cepa;

--DECLARACIÓN VARRAY DESCUENTOS       
TYPE tp_descuentos IS VARRAY(6)
    OF NUMBER;
varray_descuentos  tp_descuentos;       

BEGIN
    --TRUNCAR TABLAS
    EXECUTE IMMEDIATE('TRUNCATE TABLE RESUMEN_VENTAS_CEPA');
    EXECUTE IMMEDIATE('TRUNCATE TABLE ERRORES_PROCESO_RECAUDACION');
    --TRUNCAR Y CREAR SECUENCIA SQ_ERROR
    EXECUTE IMMEDIATE('DROP SEQUENCE SQ_ERROR');
    EXECUTE IMMEDIATE('CREATE SEQUENCE SQ_ERROR');

--POBLAR VARRAY CON DESCUENTOS CEPA Y VALOR DELIVERY
varray_descuentos:= tp_descuentos(23,21,19,17,15,1800);

--REGISTRO REG_CEPA EN CURSOR SIN PARAMETROS CUR_CEPA CICLO FOR
FOR reg_cepa IN cur_cepa LOOP

    v_num_pedidos:=0;
    v_monto_pedidos:=0;
    v_total_monto_gravamen:=0; 
    v_total_decuento_cepa:=0;
    v_monto_delivery:=0;
    v_monto_descuentos:=0;
    v_recaudacion:=0;
    
--REGISTRO REG_RESUMEN_VENTAS_CEPAS EN CURSOR CON PARAMETROS CUR_RESUMEN_VENTAS_CEPAS CICLO FOR    
FOR reg_resumen_ventas_cepas IN cur_resumen_ventas_cepas(reg_cepa.nom_cepa) LOOP
    
    --CALCULO NUM_PEDIDOS Y MONTO_PEDIDOS
    SELECT 
        COUNT(*),
        SUM(dp.subtotal)
        INTO v_num_pedidos, v_monto_pedidos
        FROM cepa CE  JOIN producto P
        ON ce.id_cepa=p.id_cepa
        JOIN detalle_pedido DP
        ON p.id_producto=dp.id_producto
        JOIN pedido PDT
        ON dp.id_pedido=pdt.id_pedido
        WHERE EXTRACT(MONTH FROM pdt.fec_pedido) = :b_mes AND EXTRACT(YEAR FROM pdt.fec_pedido) = :b_annio
        AND p.id_cepa=reg_resumen_ventas_cepas.id_cepa
        GROUP BY ce.nom_cepa;
        
        --CALCULO GRAVAMENES
        IF reg_resumen_ventas_cepas.subtotal > 0 THEN
        BEGIN
            SELECT
                pctgravamen/100
                INTO v_pct_gravamen
            FROM gravamen
            WHERE reg_resumen_ventas_cepas.subtotal BETWEEN mto_venta_inf AND mto_venta_sup;
            v_monto_gravamen:= ROUND(reg_resumen_ventas_cepas.subtotal * v_pct_gravamen);
            v_total_monto_gravamen:=v_total_monto_gravamen+v_monto_gravamen;
            
        --EXCEPCION PREDEFINIDA DE ORACLE MONTO_GRAVAMEN NO ENCONTRADO
          EXCEPTION
          WHEN OTHERS THEN
            v_mensaje_oracle:=SQLERRM;
            INSERT INTO ERRORES_PROCESO_RECAUDACION 
            VALUES(SQ_ERROR.NEXTVAL,v_mensaje_oracle,
            :b_usuario||' : No se encontró porcentaje de gravamen para el monto de los pedidos del día '||reg_resumen_ventas_cepas.fec_pedido);
          END;
        ELSE v_monto_gravamen := 0;
        END IF;
        
        
        --CALCULO DESCTOS_CEPA
        IF reg_resumen_ventas_cepas.id_cepa = 3 THEN
            v_descuento_cepa := (reg_resumen_ventas_cepas.subtotal * varray_descuentos(1))/100;
            v_total_decuento_cepa:=v_total_decuento_cepa+v_descuento_cepa;
        ELSIF reg_resumen_ventas_cepas.id_cepa = 5 THEN
            v_descuento_cepa := (reg_resumen_ventas_cepas.subtotal * varray_descuentos(2))/100;
            v_total_decuento_cepa:=v_total_decuento_cepa+v_descuento_cepa;
        ELSIF reg_resumen_ventas_cepas.id_cepa = 4 THEN
            v_descuento_cepa := (reg_resumen_ventas_cepas.subtotal * varray_descuentos(3))/100;
           v_total_decuento_cepa:=v_total_decuento_cepa+v_descuento_cepa;
        ELSIF reg_resumen_ventas_cepas.id_cepa = 2 THEN
            v_descuento_cepa := (reg_resumen_ventas_cepas.subtotal * varray_descuentos(4))/100;
           v_total_decuento_cepa:=v_total_decuento_cepa+v_descuento_cepa;
        ELSE
            v_descuento_cepa:=(reg_resumen_ventas_cepas.subtotal * varray_descuentos(5))/100;
            v_total_decuento_cepa:=v_total_decuento_cepa+v_descuento_cepa;
        END IF;         
        
        --EXCEPCIÓN DEFINIDA POR EL USARIO SUPERA LIMITE_DECUENTO DE CEPA
        BEGIN
        IF v_descuento_cepa > :b_valor_limite THEN
            RAISE limite_descuento;       
        END IF;   
                 
        EXCEPTION
        WHEN limite_descuento THEN
        v_desct_cepa:=TO_CHAR(v_descuento_cepa,'$99g999');
        v_desct_limite := v_descuento_cepa - :b_valor_limite;
        v_descuento_cepa:= :b_valor_limite;
        v_nuevo_descuento:= v_total_decuento_cepa-v_desct_limite;
        v_total_decuento_cepa := v_nuevo_descuento;
        
        --MENSAJE EXCEPCION
        v_mensaje_oracle2:='ORA-20001 Monto de descuento sobrepasa el limite permitido';
        
        --INSERTAR VALORES EN TABLA ERRORES_PROCESO_RECAUDACION
        INSERT INTO ERRORES_PROCESO_RECAUDACION
        VALUES(SQ_ERROR.NEXTVAL,v_mensaje_oracle2,'Se reemplaza el monto de descuento calculado de'||v_desct_cepa||
            ' por el monto limite de'||TO_CHAR(:b_valor_limite,'$99g999'));
            
        END;

        --CALCULO MONTO_DELIVERY
        v_monto_delivery:=v_num_pedidos*varray_descuentos(6);
        
        --CALCULO MONTO_DESCUENTOS
        v_monto_descuentos:=v_total_monto_gravamen + v_total_decuento_cepa + v_monto_delivery;
        
        --CALCULO TOTAL_RECAUDACION
        v_recaudacion:= v_monto_pedidos - v_monto_descuentos;        
END LOOP;

--INSERTAR DATOS EN TABLA RESUMEN_VENTAS_CEPA
BEGIN 
    INSERT INTO RESUMEN_VENTAS_CEPA
        VALUES(reg_cepa.nom_cepa,v_num_pedidos,v_monto_pedidos,v_total_monto_gravamen,v_total_decuento_cepa,
        v_monto_delivery,v_monto_descuentos,v_recaudacion);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
        NULL; 
END;
END LOOP;
END;
