/// <reference path="../Prefix.d.ts" />
module Hyper.Renderer
{
	export interface ViewVectors
	{
		offset: THREE.Vector2;
		coefX: THREE.Vector2;
		coefY: THREE.Vector2;
	}
	
	export const tmpM = new THREE.Matrix4();
	export const tmpVec = new THREE.Vector4();
	export const tmpVec2 = new THREE.Vector4();
	
	export function computeViewVectorCoefFromProjectionMatrix(m: THREE.Matrix4, old?: ViewVectors): ViewVectors
	{
		if (!old) {
			old = <ViewVectors>{
				offset: new THREE.Vector2(),
				coefX: new THREE.Vector2(),
				coefY: new THREE.Vector2()
			};
		}
		
		tmpVec.set(0, 0, 1, 1);
		tmpVec.applyMatrix4(m);
		
		tmpM.getInverse(m);
		
		tmpVec2.set(0, 0, tmpVec.z, tmpVec.w);
		tmpVec2.applyMatrix4(tmpM);
		old.offset.set(tmpVec2.x, tmpVec2.y);
		
		tmpVec2.set(-1, 0, tmpVec.z, tmpVec.w);
		tmpVec2.applyMatrix4(tmpM);
		old.coefX.set(tmpVec2.x, tmpVec2.y);
		
		tmpVec2.set(0, -1, tmpVec.z, tmpVec.w);
		tmpVec2.applyMatrix4(tmpM);
		old.coefY.set(tmpVec2.x, tmpVec2.y);
		
		return old;
	}
}
