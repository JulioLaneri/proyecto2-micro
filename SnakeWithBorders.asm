
.model small
.stack 200h
.data
	; Valores iniciarles
	backgroud_color equ 0h      ;Color de fondo negro
	player_score_color equ 9d   ;Color de la puntuacion
	screen_width equ 80d        ;tamanho de la pantalla
	screen_hight equ 25d     
	
	; Jugador
	player_score_label_offset equ (screen_width-1d)*2d ;Posicion de la puntuacion 
	player_score db ?
	player_win_score equ 0FFh  
	
	; snake
	; len X 2
	snake_len dw ?
	snake_body dw player_win_score + 3h dup(?) 
	
	; for repairing the backgroud(the snake will never start at 25d*80d*2d)
	snake_previous_last_cell dw ?
	; snake movement
	; 4D/4B/48/50 - r/l/u/d. defulte - right
	RIGHT equ 4Dh
	LEFT equ 4Bh
	UP equ 48h
	DOWN equ 50h 
	
	snake_direction db ?
	
	food_location dw ?
	food_color equ 4d
	food_icon equ 05h
	food_bounders equ 2d*screen_width*2d
	; start and exit                       
	
	EXIT db 0h
	START_AGAIN db 0h
	; 39h = bios code for the space key
	START_AGAIN_KEY equ 39h
	END_GAME_KEY equ 01h
	; messeges
	msg_game_over db '    JUEGO TERMINADO!:(  Presiona Esc para salir del juego' ,0Ah , 0Dh , '$'
	msg_game_over2 db '              Presiona Espacio para volver a jugar',0Ah , 0Dh , '$'
	msg_game_win db 'YOU HAVE WON THE GAME BADASS!!:)  PRESS ANY KEY TO EXIT' ,0Ah , 0Dh , '$'
	
	msg_start_game db 10,13, 'Bienvenido a SNAKE!', 0Dh, 0Ah, '$'
    msg_select_difficulty db 10,13,'Seleccione la dificultad: (0) Dificil, (1) Medio, (2) Facil', 0Dh, 0Ah, '$'
    msg_invalid_option db 10,13, 'Opcion invalida. Intente nuevamente.', 0Dh, 0Ah, '$'
    dificultad db ?  
    const_velocidad db 4d
    velocidad dw ?
	 border_char db '#'
    border_color equ 07h ; Blanco sobre negro
    
	
	;Ex2q3 write register content
	;initializing ascii array with every possible combenation of ?? 0-F
	ascii db 16 dup ('0') 
	db 16 dup ('1') 
	db 16 dup ('2') 
	db 16 dup ('3') 
	db 16 dup ('4') 
	db 16 dup ('5') 
	db 16 dup ('6') 
	db 16 dup ('7')
	db 16 dup ('8')
	db 16 dup ('9') 
	db 16 dup ('A')
	db 16 dup ('B')
	db 16 dup ('C') 
	db 16 dup ('D')
	db 16 dup ('E') 
	db 16 dup ('F')
	db 16 dup ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F')
.code
MAIN:
    ; Inicialización de segmento de datos
    mov ax, @data
    mov ds, ax	
    call MENU
    call INIT_GAME
    
    ; Bucle principal infinito con la tecla de escape (esc) y opciones de fin del juego o victoria
    MAIN_LOOP:	
        ; Siguiente frame
        call MOVE_SNAKE
        call PRINT_SNAKE
        call CHECK_SNAKE_AET_FOOD
        call CHECK_SNAKE_IN_BORDERS
        call CHECK_SNAKE_NOOSE
        call GET_DIRECTION_BY_KEY
        call MAIN_LOOP_FRAME_RATE
        
        ; Si exit está activado, finalizar el juego y volver al SO
        cmp [EXIT], 1h
        jnz MAIN_LOOP
        
        ; Empezar de nuevo
        cmp [START_AGAIN], 1h
        jz MAIN
        
        call INIT_SCREEN_BACK_TO_OS
        ; Devolver al SO
        mov ah, 4ch
        int 21h	
INIT_GAME proc near
	mov byte ptr [player_score],0h
	mov byte ptr [snake_direction],RIGHT
	mov word ptr [snake_previous_last_cell],screen_width*screen_hight*2d
	mov word ptr [food_location],8d*screen_width*2d + 10d*2d
	mov byte ptr [EXIT],0h
	mov byte ptr [START_AGAIN],0h
	
	call INIT_SCREEN
	call INIT_SNAKE_BODY

	ret
INIT_GAME endp	

; if it is, it's GAME OVER. the snake is noose if the head has the same location as one of its body cells
CHECK_SNAKE_NOOSE proc near
	push si
	push ax
	
	mov ax,snake_body[0h]
	mov si,2h
	CHECK_SNAKE_NOOSE_LOOP:
		; if ax == snake body[si] its game over
		cmp ax,snake_body[si]
		jz CHECK_SNAKE_NOOSE_GAME_OVER
		; next iteration
		add si,2h
		cmp si,snake_len
		jnz CHECK_SNAKE_NOOSE_LOOP

	jmp END_CHECK_SNAKE_NOOSE

CHECK_SNAKE_NOOSE_GAME_OVER:
	call GAME_OVER
	
END_CHECK_SNAKE_NOOSE:
	pop ax
	pop si
	ret
CHECK_SNAKE_NOOSE endp
; for now, N and S(E and W is fine)
CHECK_SNAKE_IN_BORDERS proc near
	push ax
	mov ax,snake_body[0h]
	;S
	cmp ax,screen_width*screen_hight*2h
	jb CHECK_SNAKE_IN_BORDERS_VALID

	call GAME_OVER
	
CHECK_SNAKE_IN_BORDERS_VALID:	
	pop ax
	ret
CHECK_SNAKE_IN_BORDERS endp

CHECK_SNAKE_AET_FOOD proc near
	push ax
	push si
	mov ax, snake_body[0h]
	cmp ax,food_location
	jnz END_CHECK_SNAKE_AET_FOOD
	; gemerate new food location
	call GENERATE_RANDOM_FOOD_LOCATION
	; print it to the screen
	mov si,[food_location]
	mov al,food_icon
	mov ah,food_color
	mov es:[si],ax
	; make the snake bigger
	mov ax,[snake_previous_last_cell]
	mov si,[snake_len]
	mov snake_body[si],ax
	add [snake_len],2d
	; add score
	inc byte ptr [player_score]
	call PRINT_PLAYER_SCORE
	
		
END_CHECK_SNAKE_AET_FOOD:
	pop si
	pop ax
	ret
CHECK_SNAKE_AET_FOOD endp

GENERATE_RANDOM_FOOD_LOCATION proc near
	push ax
	push dx
	push si
	push bx
    GENERATE_RANDOM_FOOD_LOCATIPN_AGAIN:  
    
    	mov ah,0h
    	INT 1Ah
    	mov ax,dx
    	mov dx,cx
    	add dx,[snake_len]
    	add dx,[snake_len]
    	; div 16-bit dx:ax/operant -> dx = mod, ax = result
    	mov cx, screen_width*screen_hight*2h - food_bounders
    	div cx
    	;get rid of the last bit
    	and dx,0FFFEh
    	add dx, food_bounders/2d
    	;check if the food is on the snake
    	mov si,0d
    	GENERATE_RANDOM_FOOD_LOCATION_AGAIN_LOOP:
    		mov ax,snake_body[si]
    		;if the new location is on the snake, start over the whole function
    		cmp dx,ax
    		jz GENERATE_RANDOM_FOOD_LOCATIPN_AGAIN
    		add si,2d
    		cmp si,[snake_len]
    		jnz GENERATE_RANDOM_FOOD_LOCATION_AGAIN_LOOP
    		
    	;update food location
    	mov [food_location], dx
	                                     
	    mov ah, 02h 
	    mov dl, 07d
	    int 21h
	    
	pop bx
	pop si
	pop dx
	pop ax
	ret
GENERATE_RANDOM_FOOD_LOCATION endp  

MAIN_LOOP_FRAME_RATE proc near
	push ax
	push cx
	push dx
	push bx
	;make the game faster
	mov bx,0h
	mov bl,[player_score]
	mov cl,4d
	shr bx,cl
	;delay cx:dx micro sec (10^-6)
	mov al,0
	mov ah,86h
	mov cx, velocidad	
	mov dx,0000h
	sub dx,bx
	int 15h
	
	pop bx
	pop dx
	pop cx
	pop dx
	ret
MAIN_LOOP_FRAME_RATE endp



GAME_OVER proc near 
	push dx
	push ax
	push bx   
	
	; Limpiar la pantalla
    mov ax, 0600h
    mov bh, 07h ; Color de fondo y de texto (blanco sobre negro)
    mov cx, 0000h
    mov dx, 184Fh ; Especifica el ?rea de la pantalla a limpiar (toda la pantalla)
    int 10h

	; print game over msg
	mov dx, offset msg_game_over
	mov ah, 9h
	int 21h
	
	; print game over msg2
	mov dx, offset msg_game_over2
	mov ah, 9h
	int 21h
    GAME_OVER_GET_OTHER_KEY:
    	; clear key buffer
    	mov ah,0Ch
    	int 21h	
    	; get key
    	mov ax,0h
    	mov ah,0h
    	int 16h	
    	
    	cmp ah, END_GAME_KEY
    	jz END_GAME_OVER
    	
    	cmp ah, START_AGAIN_KEY
    	jz GAME_OVER_START_AGAIN
    	
    	jmp GAME_OVER_GET_OTHER_KEY
    
    
    GAME_OVER_START_AGAIN:
        ; Limpiar la pantalla
        mov ax, 0600h
        mov bh, 07h ; Color de fondo y de texto (blanco sobre negro)
        mov cx, 0000h
        mov dx, 184Fh ; Especifica el ?rea de la pantalla a limpiar (toda la pantalla)
        int 10h

    	mov [START_AGAIN],1h
    
    END_GAME_OVER:		
    	; clear key buffer
    	mov ah,0Ch
    	int 21h	
    	
    	mov byte ptr [EXIT],1h
    	
    	pop bx
    	pop ax
    	pop dx
    	ret
    GAME_OVER endp 

MOVE_SNAKE proc near
	push ax
	push bx
	; save snake_previous_last_cell(for backgroud repairing)
	mov bx,snake_len
	mov ax,snake_body[bx - 2d]
	mov [snake_previous_last_cell],ax
	
	mov ax,snake_body[0h]
	call SHR_ARRAY
	; RIGHT
	cmp byte ptr [snake_direction],RIGHT
	jz MOVE_RIGHT
	; LEFT
	cmp byte ptr [snake_direction],LEFT
	jz MOVE_LEFT
	; UP
	cmp byte ptr [snake_direction],UP
	jz MOVE_UP
	; DOWN
	cmp byte ptr [snake_direction],DOWN
	jz MOVE_DOWN

	
	MOVE_RIGHT:
		add ax,2d
		jmp MOVE_TO_DIRECTION
	MOVE_LEFT:
		sub ax, 2d
		jmp MOVE_TO_DIRECTION
	MOVE_UP:
		sub ax, screen_width*2d
		jmp MOVE_TO_DIRECTION
	MOVE_DOWN:
		add ax, screen_width*2d
		jmp MOVE_TO_DIRECTION
		
MOVE_TO_DIRECTION:
	;add the new head cell
	mov snake_body[0h],ax
	
	pop bx
	pop ax
	ret
MOVE_SNAKE endp

PRINT_SNAKE proc near
	push ax
	push si
	push bx               
	
	mov bx,[snake_previous_last_cell]
	mov al,0h
	mov ah,backgroud_color
	mov es:[bx],ax
	
	;print head
	mov al,0fh
	mov ah, 0fh
	mov bx, snake_body[0d]
	mov es:[bx], ax
	;if the snake has no body(only head) - jump to the end of the function
	cmp snake_len,2h
	jz END_PRINT_SNAKE
	;print the rest if the snake
	;snake color(body)
	mov al, 176D
	mov ah, 10h
	
	mov si,2h
	PRINT_SNAKE_LOOP:
		mov bx, snake_body[si]
		mov es:[bx], ax
		;next iteration	
		add si,2h
		cmp si, [snake_len]
		jnz PRINT_SNAKE_LOOP
		
END_PRINT_SNAKE:	
	pop bx
	pop si
	pop ax
	ret
PRINT_SNAKE endp

PRINT_PLAYER_SCORE proc near
	push ax
	push bx
	mov ah,player_score_color
	
	mov bx,0h
	mov bl,[player_score]
	; low
	mov al, ascii[bx + 256d]
	mov es:[player_score_label_offset],ax
	; height
	mov al, ascii[bx]
	mov es:[player_score_label_offset-2d],ax
	; label
	mov al,':'
	mov es:[player_score_label_offset-4d],ax
	
	mov al,'S'
	mov es:[player_score_label_offset-6d],ax
	
	mov al,'O'
	mov es:[player_score_label_offset-8d],ax
	
	mov al,'T'
	mov es:[player_score_label_offset-10d],ax
	
	mov al,'N'
	mov es:[player_score_label_offset-12d],ax
	
	mov al,'U'
	mov es:[player_score_label_offset-14d],ax  
	 
	mov al,'P'
	mov es:[player_score_label_offset-16d],ax
	

	pop bx
	pop ax
	ret
PRINT_PLAYER_SCORE endp  
DRAW_BORDER proc near
    push ax
    push bx
    push cx
    push si

    ; Establecer segmento de pantalla
    mov ax, 0b800h
    mov es, ax

    ; Obtener el carácter y el color del borde
    mov al, border_char
    mov ah, border_color

    ; Dibujar el borde superior
    mov cx, screen_width
    mov si, 0
    rep stosw

    ; Dibujar el borde inferior
    mov cx, screen_width
    mov si, (screen_width * (screen_hight - 1)) * 2
    rep stosw

    ; Dibujar los bordes izquierdo y derecho
    mov cx, screen_hight
    mov bx, screen_width * 2
    mov si, 0

    DRAW_LEFT_RIGHT_BORDER:
        mov es:[si], ax
        mov es:[si + bx - 2], ax
        add si, bx
        loop DRAW_LEFT_RIGHT_BORDER

    pop si
    pop cx
    pop bx
    pop ax
    ret
DRAW_BORDER endp
INIT_SCREEN proc near
    push ax
    push cx
    push si
    ; Modo gráfico
    mov ah, 00h
    mov al, 13h
    int 10h
    ; Establecer segmento de pantalla
    mov ax, 0b800h
    mov es, ax
    ; Limpiar la pantalla
    mov ax, 03h
    int 10h
    
    ; Llamar a la rutina para dibujar el borde
    call DRAW_BORDER

    call PRINT_PLAYER_SCORE
    ; Escribir la primera comida
    mov si, [food_location]
    mov al, food_icon
    mov ah, food_color
    mov es:[si], ax
    
    ; Ocultar cursor de texto
    pop si
    pop cx
    pop ax
    ret
INIT_SCREEN endp

INIT_SCREEN_BACK_TO_OS proc near
	push ax
	push cx
	;clear the screen
	mov ax, 03h
	int 10h
	; normal text mode
	mov ah,03h
	mov al,13h
	int 10h

	pop cx
	pop ax
	ret
INIT_SCREEN_BACK_TO_OS endp

 
INIT_SNAKE_BODY proc near
	; init snake_body
	mov word ptr snake_body[6d],4d + 3d*screen_width*2d
	mov word ptr snake_body[4d],6d + 3d*screen_width*2d
	mov word ptr snake_body[2d],8d + 3d*screen_width*2d
	mov word ptr snake_body[0d],10d + 3d*screen_width*2d
	; sizeX2
	mov word ptr [snake_len],8d

	ret
INIT_SNAKE_BODY endp
; update [direction] accordingly. if there is no new key-event direction will stay the same.
; ecs will quit the game
GET_DIRECTION_BY_KEY proc near
	; check for a key storke
	push ax
	push bx
	mov ax, 0h
	mov ah,01h
	int 16h	
	
	; zero flag is on if there was no event
	jz END_GET_DIRECTION_BY_KEY
	; esc key
	cmp ah,END_GAME_KEY
	jz GET_DIRECTION_BY_KEY_EXIT_GAME_IS_ON
	
	;if |new direction - old direction| == 3d or 5d it's a valid move(the snake cant turn backward)
	mov bh,ah
	mov bl,[snake_direction]
	sub bh,bl
	cmp bh,3d
	jz GET_DIRECTION_BY_KEY_VALID_MOVE
	cmp bh,5d
	jz GET_DIRECTION_BY_KEY_VALID_MOVE
	neg bh
	cmp bh,3d
	jz GET_DIRECTION_BY_KEY_VALID_MOVE
	cmp bh,5d
	jz GET_DIRECTION_BY_KEY_VALID_MOVE
	; invalid move:
	; clear key buffer
	mov ah,0Ch
	int 21h	
	jmp END_GET_DIRECTION_BY_KEY
	
GET_DIRECTION_BY_KEY_VALID_MOVE:
	mov [snake_direction], ah
	; clear key buffer
	mov ah,0Ch
	int 21h	

	jmp END_GET_DIRECTION_BY_KEY
GET_DIRECTION_BY_KEY_EXIT_GAME_IS_ON:
	mov byte ptr [EXIT], 1h
	; clear key buffer
	mov ah,0Ch
	int 21h	
END_GET_DIRECTION_BY_KEY:
	pop bx
	pop ax
	ret
GET_DIRECTION_BY_KEY endp

; the last cell overrided
SHR_ARRAY proc near
	push bx
	push ax
	push si
	
	mov si,[snake_len]
	sub si,2h
	L1:
		mov ax,snake_body[si - 2h]
		mov snake_body[si], ax
		;next iteration
		sub si,2h
		cmp si,0h
		jnz L1
	pop si
	pop ax
	pop bx
	ret
SHR_ARRAY endp   

MENU proc near  
    ; Imprimir el mensaje de inicio del juego
    mov dx, offset msg_start_game
    mov ah, 9h
    int 21h

    SeleccionarDificultad:
    ; Imprimir mensaje para seleccionar la dificultad
    mov dx, offset msg_select_difficulty
    mov ah, 9h
    int 21h

    ; Leer una tecla del usuario
    mov ah, 1h
    int 21h

    ; Guardar la tecla en la variable 'dificultad'
    mov dificultad, al

    ; Verificar si la tecla es una opción válida (0, 1, 2) o 'q' para salir
    cmp al, '0'
    je OpcionValida
    cmp al, '1'
    je OpcionValida
    cmp al, '2'
    je OpcionValida
    cmp al, 'q'
    je Salir

    ; Si no es válida, imprimir mensaje de error y volver a preguntar
    mov dx, offset msg_invalid_option
    mov ah, 9h
    int 21h
    jmp SeleccionarDificultad

OpcionValida:
    ; Convertir el carácter de la tecla a un valor numérico
    sub dificultad, '0' ; '0' en ASCII es 48, por lo que resta 48 para obtener el valor numérico
    
    ; Multiplicar la dificultad por const_velocidad y guardar en velocidad
    mov al, dificultad
    mov bl, const_velocidad
    mul bl
    mov velocidad, ax
    
    ret

Salir:
    ; Salir del menú
    ; (aquí puedes agregar código para manejar la salida del juego si es necesario)

    ret

MENU endp


	
end MAIN
	
